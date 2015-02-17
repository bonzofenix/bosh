require 'spec_helper'
require 'rack/test'

module Bosh
  module Director
    module Api
      module Controllers
        class TestController < BaseController
          def initialize(identity_provider, always_authenticated=nil)
            super(identity_provider)
            @always_authenticated_override = always_authenticated
          end
          get '/test_route' do
            "Success with: #{@user || 'No user'}"
          end

          def always_authenticated?
            @always_authenticated_override.nil? ? super : @always_authenticated_override
          end
        end

        describe BaseController do
          include Rack::Test::Methods

          subject(:app) { TestController.new(identity_provider, always_authenticated) }

          let(:always_authenticated) { nil }
          let(:identity_provider) { LocalIdentityProvider.new(UserManager.new) }

          let(:temp_dir) { Dir.mktmpdir }
          let(:test_config) { base_config }
          let(:base_config) {
            blobstore_dir = File.join(temp_dir, 'blobstore')
            FileUtils.mkdir_p(blobstore_dir)

            config = Psych.load(spec_asset('test-director-config.yml'))
            config['dir'] = temp_dir
            config['blobstore'] = {
              'provider' => 'local',
              'options' => {'blobstore_path' => blobstore_dir}
            }
            config['snapshots']['enabled'] = true
            config
          }

          before { App.new(Config.load_hash(test_config)) }

          after { FileUtils.rm_rf(temp_dir) }

          it 'sets the date header' do
            get '/test_route'
            expect(last_response.headers['Date']).not_to be_nil
          end

          it 'requires authentication' do
            get '/test_route'
            expect(last_response.status).to eq(401)
          end

          it 'requires authentication even for invalid routes' do
            get '/invalid_route'
            expect(last_response.status).to eq(401)
          end

          context 'when authenticated' do
            before { basic_authorize 'admin', 'admin' }

            it 'succeeds' do
              get '/test_route'
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('Success with: admin')
            end
          end

          context 'when the controller overrides the default auth requirements' do
            let(:always_authenticated) { false }

            it 'skips authorization' do
              get '/test_route'
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('Success with: No user')
            end

            it 'skips authorization for invalid routes' do
              get '/invalid_route'
              expect(last_response.status).to eq(404)
            end
          end
        end
      end
    end
  end
end
