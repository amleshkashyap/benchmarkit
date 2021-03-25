class V1::Api::ApiUserObjectsController < ApiController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  def create_user_object
    if params[:id].nil?
      render_400 and return
    end

    @user = User.find(params[:id])

    if @user.nil?
      render_404("User Not Found") and return
    end

    if @user.user_object_exists?
       render_404("User Object Not Found") and return
    end

    @user_object = UserObject.new(:user_id => @user.id)

    if @user_object.save
      render_200("User Object Created") and return
    else
      render_500("User Object Creation Failed, Retry") and return
    end
  end

  def add_user_method
    if params[:id].nil? || params[:textfile].nil? || params[:name].nil?
      render_400 and return
    end

    @user_object = UserObject.find_by(:user_id => params[:id])

    if @user_object.nil?
      render_404 and return
    end

    if @user_object.method_exists?(params[:name])
      render_500("Method Name Already Exists") and return
    end

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
    if params[:id].nil?
      render_400 and return
    end

    @user_object = UserObject.find_by(:user_id => params[:id])

    if @user_object.nil?
      render_404 and return
    end

    render_200("Success", { :method_list => @user_object.stored_methods, :caution => "Some Or All Of These Methods Maybe Invalid" }) and return
  end

  def execute_user_method
    if params[:id].nil? || params[:name].nil?
      render_400 and return
    end

    @user_object = UserObject.find_by(:user_id => params[:id])

    if @user_object.nil?
      render_404 and return
    end

    if !@user_object.method_exists?(params[:name])
      render_404("Method Not Found") and return
    end

    @user_object.executing_method!

    @user_object.create_user_method(params[:name], @user_object.get_method(params[:name]))
    @user_object.extend_method_expiry(params[:name])

    result = @user_object.send(params[:name])
#    result = UserObject.send(params[:name])

    @user_object.work_done!

    render_200("Success", { :result => result }) and return
  end

end
