class QueueController < ApplicationController
  allow_unauthenticated_access

  def index
    @jobs = SolidQueue::Job.order(created_at: :desc).limit(100)
    @processes = SolidQueue::Process.all
    @failed_jobs = SolidQueue::FailedExecution.includes(:job).order(created_at: :desc).limit(50)
  end
end
