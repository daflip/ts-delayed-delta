require 'delayed_job'
require 'thinking_sphinx'

# Delayed Deltas for Thinking Sphinx, using Delayed Job.
#
# This documentation is aimed at those reading the code. If you're looking for
# a guide to Thinking Sphinx and/or deltas, I recommend you start with the
# Thinking Sphinx site instead - or the README for this library at the very
# least.
#
# @author Patrick Allan
# @see http://ts.freelancing-gods.com Thinking Sphinx
#
class ThinkingSphinx::Deltas::DelayedDelta < ThinkingSphinx::Deltas::DefaultDelta

  def self.cancel_jobs
    Delayed::Job.delete_all(
      "handler LIKE '--- !ruby/object:ThinkingSphinx::Deltas::%'"
    )
  end

  def self.enqueue_unless_duplicates(object)

    # if we're running as a DJ worker then just do the work now!
    return object.perform if Delayed::Job.running_as_dj_worker?

    return if Delayed::Job.where(
      :checksum => Digest::MD5.hexdigest(object.to_yaml),
      :locked_at => nil,
    ).count > 0

    Delayed::Job.enqueue object, :priority => priority
  end

  def self.priority
    ThinkingSphinx::Configuration.instance.settings['delayed_job_priority'] || 0
  end

  def delete(index, instance)
    new_delete_job = ThinkingSphinx::Deltas::DelayedDelta::FlagAsDeletedJob.new(
      index.name, index.document_id_for_key(instance.id)
    )

    # if we're running as a DJ worker then just do the work now!
    return new_delete_job.perform if Delayed::Job.running_as_dj_worker?

    Delayed::Job.enqueue new_delete_job, :priority => self.class.priority
  end

  # Adds a job to the queue for processing the given index.
  #
  # @param [Class] index the Thinking Sphinx index object.
  #
  def index(index)
    self.class.enqueue_unless_duplicates(
      ThinkingSphinx::Deltas::DelayedDelta::DeltaJob.new(index.name)
    )
  end
end

Delayed::Job.class_eval do
  before_save :calculate_checksum
  attr_accessible :checksum
  def calculate_checksum
    self.checksum = Digest::MD5.hexdigest(self.handler)
  end

  # sorry - i couldn't find an easier way to detect this
  def self.running_as_dj_worker?
    $0.to_s.match /rake|delayed_job/
  end
end

require 'thinking_sphinx/deltas/delayed_delta/delta_job'
require 'thinking_sphinx/deltas/delayed_delta/flag_as_deleted_job'
require 'thinking_sphinx/deltas/delayed_delta/railtie' if defined?(Rails)
