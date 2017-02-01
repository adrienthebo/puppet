require 'puppet/face'
require 'puppet/state_machine'

BOOTSTRAP_CA = Puppet::StateMachine.build("bootstrap ca") do |m|
  m.start_state(:start)

  # TODO
  #   * Lock and unlock SSL directory
  #   * Enable HTTP verification after CA cert has been downloaded
  #

  m.state :start,
    action: -> { Puppet::SSL::Host.ca_location = :remote },
    event: ->(_) { :read_ca_cert },
    transitions: {read_ca_cert: :read_ca_cert}

  m.state :read_ca_cert,
    action: -> { File.readable?(Puppet[:localcacert]) },
    event: ->(result) { result ? :ca_cert_present : :ca_cert_absent },
    transitions: {
      ca_cert_present: :read_ca_crl,
      ca_cert_absent: :fetch_ca_cert
    }

  m.state :fetch_ca_cert,
    action: -> do
      http = Puppet::Network::HttpPool.http_instance(Puppet[:ca_server], Puppet[:ca_port], true, false)
      resp = http.get('/puppet-ca/v1/certificate/ca?environment=production')
      if resp.code == '200'
        File.open(Puppet[:localcacert], 'w:ASCII') { |fh| fh.write(resp.body) }
      end
    end,
    event: ->(result) { result ? :ca_cert_fetched : :ca_cert_absent },
    transitions: {
      ca_cert_fetched: :read_ca_crl,
      ca_cert_absent: :ca_cert_unretrievable
    }

  m.state :read_ca_crl,
    action: -> { File.readable?(Puppet[:hostcrl]) },
    event: ->(result) { result ? :ca_crl_present : :ca_crl_absent },
    transitions: {
      ca_crl_present: :complete,
      ca_crl_absent: :fetch_ca_crl,
    }

  m.state :fetch_ca_crl,
    action: -> do
      http = Puppet::Network::HttpPool.http_instance(Puppet[:ca_server], Puppet[:ca_port], true, false)
      resp = http.get('/puppet-ca/v1/certificate_revocation_list/ca?environment=production')
      if resp.code == '200'
        File.open(Puppet[:hostcrl], 'w:ASCII') { |fh| fh.write(resp.body) }
      end
    end,
    event: ->(result) { result ? :ca_crl_fetched : :ca_crl_absent },
    transitions: {
      ca_crl_fetched: :complete,
      ca_crl_absent: :ca_crl_unretrievable
    }

  m.state :complete, type: :final
  m.state :error, type: :error
  m.state :ca_cert_unretrievable, type: :error
  m.state :ca_crl_unretrievable, type: :error
end

Puppet::Face.define(:ssl, '0.1.0') do
  action(:bootstrap_client) do
    when_invoked do |opts|
      Puppet.settings.preferred_run_mode = "agent"
      Puppet.settings.use(:main, :ssl)
      begin
        BOOTSTRAP_CA.call
      rescue Exception => e
        puts e
        puts e.backtrace.join("\n")
      end
    end

    when_rendering :console do |value|
      value.inspect
    end
  end
end
