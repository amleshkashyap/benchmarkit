class ApiController < ApplicationController

  { "400" => "Invalid Or Missing Params", "401" => "Unauthorized", "403" => "Forbidden", "404" => "Not Found", "500" => "Internal Error" }.each do |key, value|
    define_method "render_#{key}".to_sym do |msg = value, resp = {}|
      resp['error'] = msg
      render :json => resp, :status => key.to_i
    end
  end

  def render_200(msg = "Success", resp = {})
    resp['message'] = msg
    render :json => resp, :status => 200
  end

end
