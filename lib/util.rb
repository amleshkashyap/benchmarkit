require "benchmark"

module Util

  def self.redis
    Rails.configuration.redis
  end

  def self.redis_get(key)
    self.redis.get(key)
  end

  def self.redis_set(key, value)
    return true if self.redis.set(key, value)
  end

  def self.redis_set_json(key, value)
    return true if self.redis.set(key, value.to_json)
  end

  def self.redis_add_to_hash(hash_key, key, value)
    return true if self.redis.hset(hash_key, key, value)
  end

  def self.redis_get_all_from_hash(hash_key)
    self.redis.hgetall(hash_key) if self.redis.exists(hash_key)
  end

  def self.redis_get_from_hash(hash_key, key)
    self.redis.hget(hash_key, key)
  end

  def self.remove_from_hash(hash_key, keys)
    # transactions aren't ACID compliant
    self.redis.multi do
      keys.for_each do |key|
        self.redis.hdel(hash_key, key) if self.redis.hexists(hash_key, key)
      end
    end
  end

  def self.redis_add_to_sorted_set(ss_key, value)
    return true if self.redis.zadd(ss_key, value)
  end

  def self.redis_get_sorted_set(ss_key, asc=false)
    if asc
      self.redis.zrange(ss_key, 0, -1)
    else
      self.redis.zrevrange(ss_key, 0, -1)
    end
  end

  def self.redis_get_top_sorted_set(ss_key, asc=false)
    if asc
      self.zrange(ss_key, 0, 0)
    else
      self.redis.zrevrange(ss_key, 0, 0)
    end
  end

  def self.all_sidekiq_jobs_in_retry_set
    retry_set = Sidekiq::RetrySet.new
    array = []
    retry_set.select do |job|
      array.push(job.item)
    end
    return array
  end

  def self.all_sidekiq_jobs_in_dead_set
    dead_set = Sidekiq::DeadSet.new
    array = []
    dead_set.select do |job|
      array.push(job.item)
    end
    return array
  end

  def self.all_sidekiq_jobs_in_scheduled_set
    job_set = Sidekiq::ScheduledSet.new
    array = []
    job_set.select do |job|
      array.push(job.item)
    end
    return array
  end

  def self.find_in_retry_set(jid)
    retry_set = Sidekiq::RetrySet.new
    job = retry_set.find_job(jid)
    return job.item.merge!(:set => 'retry') if !job.nil?
    return nil
  end

  def self.find_in_dead_set(jid)
    dead_set = Sidekiq::DeadSet.new
    job = dead_set.find_job(jid)
    return job.item.merge!(:set => 'dead') if !job.nil?
    return nil
  end

  def self.cleanup_arguments(result)
    return true if result == 'true'
    return false if result == 'false'
  end

end
