class V1::Api::UserObjectController < ApiController

  skip_before_action :verify_authenticity_token

  def create_user_object
    render_500("User Object Already Exists") and return if current_user.user_object_exists?
    @user_object = UserObject.new(:user_id => current_user.id)
    if @user_object.save
      render_200("User Object Created") and return
    else
      render_500("User Object Creation Failed, Retry") and return
    end
  end

  def add_user_method
    render_400 and return if missing_required_params?(['textfile', 'name'])
    @user_object = UserObject.find_by(:user_id => current_user.id)
    render_404 and return if @user_object.nil?
    render_500("Method Name Already Exists") and return if @user_object.method_exists?(params[:name])

    @user_object.adding_method!
    file_name = params[:textfile].tempfile
    snippet = Util.extract_code(file_name)

    @code = Code.new(:snippet => snippet, :script_id => 1)
    if @code.is_sanitized_snippet?
      @user_object.create_user_method(params[:name], snippet)
      result = @user_object.send(params[:name].to_sym)
#      UserObject.create_user_method(params[:name], snippet)
      @user_object.add_method(params[:name], snippet)
      @user_object.work_done!
      render_200("Added Method Successfully", { :result => result }) and return
    else
      @user_object.work_done!
      render_500("Sanitization Failed, Change And Resubmit") and return
    end
  end

  def list_user_methods
    @user_object = UserObject.find_by(:user_id => current_user.id)
    render_404 and return if @user_object.nil?

    render_200("Success", { :method_list => @user_object.stored_methods, :caution => "Some Or All Of These Methods Maybe Invalid", :user => current_user }) and return
  end

  def execute_user_method
    render_400 and return if missing_required_params?(['name'])
    @user_object = UserObject.find_by(:user_id => current_user.id)
    render_404 and return if @user_object.nil?
    render_404("Method Not Found") and return if !@user_object.method_exists?(params[:name])

    @user_object.executing_method!
    @user_object.create_user_method(params[:name], @user_object.get_method(params[:name]))
    @user_object.extend_method_expiry(params[:name])
    result = @user_object.send(params[:name])
#    result = UserObject.send(params[:name])
    @user_object.work_done!
    render_200("Success", { :result => result }) and return
  end

end
