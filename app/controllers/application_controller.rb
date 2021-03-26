class ApplicationController < ActionController::Base
  protect_from_forgery
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  def missing_required_params?(args)
    args.each do |arg|
      return true if params[arg].nil?
    end
    return false
  end

  def missing_optional_params?(args)
    args.each do |arg|
      return false if !params[arg].nil?
    end
    return true
  end

  def invalid_param_values?(name, args)
    return true if args.include?(params[name])
    return false
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :email])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :email])
  end

end
