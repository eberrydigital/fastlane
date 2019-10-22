require 'spaceship'

module Fastlane
  module Actions
    module SharedValues
    end

    # This whole action is an adaption of pem/lib/pem/manager.rb
    class GetApplePayIdentifierCertificateAction < Action
      def self.run(params)
        login(params)
        create_certificate(params)
      end

      def self.login(params)
        UI.message("Starting login with user '#{params[:username]}'")
        Spaceship.login(params[:username], nil)
        Spaceship.client.select_team(team_id: params[:team_id], team_name: params[:team_name])
        UI.message("Successfully logged in")
      end

      def self.create_certificate(params)
        UI.important("Creating a new Apple Pay certificate.")

        csr, pkey = Spaceship.certificate.create_certificate_signing_request

        begin
          cert = certificate.create!(csr: csr, bundle_id: params[:merchant_bundle_id])
        rescue => ex
          if ex.to_s.include?("You already have a current")
            UI.message(ex.to_s)
            UI.user_error!("You already have 2 Apple Pay certificates for this merchant. You'll need to revoke an old certificate to make room for a new one.")
          else
            raise ex
          end
        end

        x509_certificate = cert.download

        filename_base = params[:merchant_bundle_id]
        filename_base = File.basename(filename_base, ".pem") # strip off the .pem if it was provided.

        output_path = File.expand_path('.')
        FileUtils.mkdir_p(output_path)

        if params[:save_private_key]
          private_key_path = File.join(output_path, "#{filename_base}.pkey")
          File.write(private_key_path, pkey.to_pem)
          UI.message("Private key: ".green + Pathname.new(private_key_path).realpath.to_s)
        end

        if params[:generate_p12]
          p12_cert_path = File.join(output_path, "#{filename_base}.p12")
          p12 = OpenSSL::PKCS12.create(params[:p12_password], 'production', pkey, x509_certificate)
          File.write(p12_cert_path, p12.to_der)
          UI.message("p12 certificate: ".green + Pathname.new(p12_cert_path).realpath.to_s)
        end

        x509_cert_path = File.join(output_path, "#{filename_base}.pem")
        File.write(x509_cert_path, x509_certificate.to_pem + pkey.to_pem)
        UI.message("PEM: ".green + Pathname.new(x509_cert_path).realpath.to_s)
        return x509_cert_path
      end

      def self.certificate
        Spaceship.certificate.apple_pay_merchant_identity
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.is_supported?(platform)
        [:ios].include?(platform)
      end

      def self.description
        'Creates an Apple Pay certificate'
      end

      def self.details
        "This action allows you to create an Apple Pay merchant certificate."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :username,
                                       env_name: "APPLE_PAY_USERNAME",
                                       description: "Your Apple ID Username"),
          FastlaneCore::ConfigItem.new(key: :merchant_bundle_id,
                                   env_name: "APPLE_PAY_MERCHANT_BUNDLE_ID",
                                   description: "You merchant bundle identifier (e.g: merchant.com.example)"),
          FastlaneCore::ConfigItem.new(key: :team_id,
                                 short_option: "-b",
                                 env_name: "APPLE_PAY_CERT_TEAM_ID",
                                 code_gen_sensitive: true,
                                 default_value: CredentialsManager::AppfileConfig.try_fetch_value(:team_id),
                                 default_value_dynamic: true,
                                 description: "The ID of your Developer Portal team if you're in multiple teams",
                                 optional: true),
          FastlaneCore::ConfigItem.new(key: :team_name,
                                       short_option: "-l",
                                       env_name: "APPLE_PAY_CERT_TEAM_NAME",
                                       description: "The name of your Developer Portal team if you're in multiple teams",
                                       optional: true,
                                       code_gen_sensitive: true,
                                       default_value: CredentialsManager::AppfileConfig.try_fetch_value(:team_name),
                                       default_value_dynamic: true),
          FastlaneCore::ConfigItem.new(key: :p12_password,
                                     short_option: "-p",
                                     env_name: "APPLE_PAY_CERT_P12_PASSWORD",
                                     sensitive: true,
                                     description: "The password that is used for your .p12 file",
                                     default_value: ""),
          FastlaneCore::ConfigItem.new(key: :generate_p12,
                                     env_name: "APPLE_PAY_CERT_GENERATE_P12_FILE",
                                     description: "Generate a p12 file additionally to the .pem file",
                                     is_string: false,
                                     default_value: true),
          FastlaneCore::ConfigItem.new(key: :save_private_key,
                                    short_option: "-s",
                                    env_name: "APPLE_PAY_CERT_SAVE_PRIVATEKEY",
                                    description: "Set to save the private RSA key",
                                    is_string: false,
                                    default_value: true)
        ]
      end

      def self.author
        ['rishabhtayal', 'janpio']
      end

      def self.example_code
        [
          'get_apple_pay_identifier_certificate(
            username: "test@example.com",
            merchant_bundle_id: "merchant.com.rtayal.app",
            p12_password: "test"
          )',
          'get_apple_pay_identifier_certificate(
            username: "test@example.com",
            merchant_bundle_id: "merchant.com.rtayal.app",
            p12_password: "test",
            team_id: "XXXXXXX"
          )'
        ]
      end

      def self.category
        :misc
      end
    end
  end
end
