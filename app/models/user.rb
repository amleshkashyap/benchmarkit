class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable, :lockable
  has_many :scripts

  def user_object_exists?
    @user_object = UserObject.find_by(:user_id => self.id)
    return true unless @user_object.nil?
    return false
  end
end
