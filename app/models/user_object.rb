class UserObject < ApplicationRecord
  include AASM

  VALID_STATUSES = ['adding', 'executing', 'idle']
  DEFAULT_REDIS_EXPIRY = 3600

  aasm column: 'status' do
    state :idle, initial: true
    state :adding
    state :executing

    event :adding_method do
      transitions from: [:idle], to: :adding
    end

    event :executing_method do
      transitions from: [:idle], to: :executing
    end

    event :work_done do
      transitions from: [:adding, :executing], to: :idle
    end
  end

  def self.create_user_class_method(name, snippet)
    define_method name.to_sym do
      instance_eval snippet
    end
  end

  def create_user_method(name, snippet)
    define_singleton_method name.to_sym do
      instance_eval snippet
    end
  end

  def stored_methods
    return self.get_redis_hash.keys unless self.get_redis_hash.nil?
    return nil
  end

  def validity_expired?(valid_till)
    return true if valid_till.nil?
    return (valid_till.to_i <= Time.current.utc.to_i)
  end

  def method_exists?(name)
    @all_methods = self.stored_methods
    if !@all_methods.nil?
      valid_till = Util.redis_get_from_hash(self.get_redis_expiry_key, name)
      if self.validity_expired?(valid_till)
	Util.redis_remove_key_from_hash(self.get_redis_expiry_key, name)
	Util.redis_remove_key_from_hash(self.get_redis_key, name)
      else
        return true if @all_methods.include?(name)
      end
    end
    return false
  end

  def get_redis_key
    return "_stored_methods_" + self.user_id.to_s
  end

  def get_redis_expiry_key
    return "_stored_methods_expiries_" + self.user_id.to_s
  end

  def get_redis_hash
    return Util.redis_get_all_from_hash(self.get_redis_key)
  end

  def get_method(name)
    return Util.redis_get_from_hash(self.get_redis_key, name)
  end

  # Don't use this method without doing method_exists? first - if it gives false, add the method
  def add_method(name, snippet)
    Util.redis_add_to_hash(self.get_redis_key, name, snippet)
    Util.redis_add_to_hash(self.get_redis_expiry_key, name, (Time.current.utc + DEFAULT_REDIS_EXPIRY).to_i)
  end

  def extend_method_expiry(name)
    Util.redis_add_to_hash(self.get_redis_expiry_key, name, (Time.current.utc + DEFAULT_REDIS_EXPIRY).to_i)
  end
end
