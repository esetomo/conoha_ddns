require 'dotenv/load'
require 'net/http'
require 'json'

class ConoHaDDNS
  def call(env)
    target_fqdn = ENV['TARGET_HOST']
    remote_addr = env['X_REAL_IP'] || env['REMOTE_ADDR']    
    record_type = remote_addr.include?(':') ? 'AAAA' : 'A'
    
    uri = URI.parse(ENV['AUTH_ENDPOINT'])
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    req = Net::HTTP::Post.new(uri.request_uri)
    req['Accept'] = 'application/json'
    req["Content-Type"] = "applicaton/json"
    req.body = {
      "auth" => {
        "passwordCredentials" => {
          "username" => ENV["API_USER"],
          "password" => ENV["API_PASS"]
        },
        "tenantId" => ENV["API_TENANT"]
      }
    }.to_json

    res = https.request(req)
    result = JSON.parse(res.body)
    token = result['access']['token']['id']
    catalog = result['access']['serviceCatalog'].find{|catalog| catalog['type'] == 'dns'}
    endpoint = catalog['endpoints'][0]['publicURL']
    target_domain = target_fqdn.split('.')[1..-1].join('.')
    target_host = target_fqdn.split('.')[0]

    uri = URI.parse(endpoint)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    req = Net::HTTP::Get.new('/v1/domains')
    req['Accept'] = 'application/json'
    req['Content-Type'] = 'applicaton/json'
    req['X-Auth-Token'] = token

    res = https.request(req)
    result = JSON.parse(res.body)
    domain_id = result['domains'].find{|item| item['name'] == target_domain + "."}['id']

    req = Net::HTTP::Get.new("/v1/domains/#{domain_id}/records")
    req['Accept'] = 'application/json'
    req['Content-Type'] = 'applicaton/json'
    req['X-Auth-Token'] = token

    res = https.request(req)
    result = JSON.parse(res.body)
    record = result['records'].find{|item| item['name'] == target_fqdn + "." && item['type'] == record_type}

    return [200, {'Content-Type' => 'application/json'}, [record.to_json]] if remote_addr == record['data']

    req = Net::HTTP::Put.new("/v1/domains/#{domain_id}/records/#{record['id']}")
    req['Accept'] = 'application/json'
    req['Content-Type'] = 'application/json'
    req['X-Auth-Token'] = token
    req.body = {
      'data' => remote_addr
    }.to_json

    res = https.request(req)

    [200, {'Content-Type' => 'application/json'}, [res.body]]
  end
end

class MyAuth < Rack::Auth::Basic
  def call(env)
    request = Rack::Request.new(env)
    if request.path == '/check'
      remote_addr = env['X_REAL_IP'] || env['REMOTE_ADDR']
      return [200, {'Content-Type' => 'text/plain'}, [remote_addr]]
    end
    super
  end
end

use MyAuth do |user, pass|
  user == ENV['DDNS_USER'] && pass == ENV['DDNS_PASS']
end

run ConoHaDDNS.new
