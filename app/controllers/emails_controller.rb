require 'mail'
require 'userfriend'
require 'friend'
require 'queueclassicjob'

class EmailsController < ApplicationController
  before_action :set_email, only: [:show, :edit, :update, :destroy, :archive, :reply]

  respond_to :html, :json

  def index
    case params[:mailbox_type]
      when 'sent'
        emails = Email.select(:id, :to, :subject, :date, :friendly_date)
                     .where(user_id: current_user.id)
                     .where(sent: true)
                     .order(date: :desc)
      when 'archived'
        emails = Email.select(:id, :from, :subject, :date, :friendly_date)
                     .where(user_id: current_user.id)
                     .where("\"from\" in (?)", current_user.friends.select(:email))
                     .where(archived: true)
                     .order(date: :desc)
      when 'unknown'
        emails = Email.select(:id, :from, :subject, :date, :friendly_date)
                     .where(user_id: current_user.id)
                     .where("\"from\" not in (?)", current_user.friends.select(:email))
                     .order(date: :desc)
      else # inbox
        emails = Email.select(:id, :from, :subject, :date, :friendly_date)
                     .where(user_id: current_user.id)
                     .where("\"from\" in (?)", current_user.friends.select(:email))
                     .where(archived: false)
                     .where(sent: false)
                     .order(date: :desc)
    end
    respond_with(emails)
  end

  def show
    respond_with(@email)
  end


  def new
    friends = current_user.friends.collect do |friend|
      [friend.first_name + ' ' + friend.last_name + ' <' + friend.email + '>', friend.id]
    end
    @params = {:recipients => friends}
    @email = Email.new
    respond_with(@email)
  end

  def reply
    @params = @email.build_reply
    @email = Email.new
    render :action => :new
    #respond_with(@email)
  end

  #def edit
  #end

  def create
    sender = current_user.email
    password = current_user.email_pw
    Mail.defaults do
      delivery_method :smtp, {:address => "smtp.gmail.com",
                              :port => 587,
                              #:domain => 'your.host.name',
                              :user_name => sender,
                              :password => password,
                              :authentication => 'plain',
                              :enable_starttls_auto => true}
    end
    recipient = Friend.find(params[:email][:to].to_i).email
    subj = params[:email][:subject]
    msg = params[:email][:message]
    mail = Mail.new do
      to recipient
      from sender
      subject subj
      body msg
    end

    mail.deliver!

    @email = Email.new(:body => mail.to_s,
                       :user_id => current_user.id,
                       :archived => false,
                       :sent => true,
                       :to => recipient,
                       :from => sender,
                       :subject => subj,
                       :date => mail.date.to_i,
                       :friendly_date => mail.date.to_time.localtime.ctime)
    @email.save
    respond_with(@email)
  end

  #def update
  #  @email.update(email_params)
  #  respond_with(@email)
  #end

  #def destroy
  #  @email.destroy
  #  respond_with(@email)
  #end

  def archive
    @email.update(:archived => true)
    flash[:notice] = "Message has been archived"
    render :action => :show
  end

  def refresh
    #users_queued = QueueClassicJob.select(:args).collect { |job| job.args[0]['arguments'][0] }
    #PopJob.perform_later(current_user.id) unless users_queued.include? current_user.id
    PopJob.perform_later(current_user.id)
    render nothing: true
  end

  private
  def set_email
    @email = Email.find(params[:id])
  end

  def email_params
    params.require(:email).permit(:body, :user_id)
  end
end
