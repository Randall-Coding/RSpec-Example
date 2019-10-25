require 'rails_helper'

RSpec.describe WebhooksController, :type => :controller do
  subject{controller}
  let(:free_trial) {create(:plan, :name => "Free Trial")}
  let(:organization) {Organization.find_by_customer_token("test_token")}

  before do
      create(:plan, :name => "Small")
      create(:organization, :customer_token => "test_token",plan:free_trial)
  end

  describe "failed payment" do
    before do
      params =  {id: 1, :data => {:object => {:customer => "test_token"}}}
      MonitorMailer.stub :delinquent_account_email
      post :failed_payment, params
    end

    specify{ organization.delinquent.should be(true)}
    specify{ MonitorMailer.should have_received(:delinquent_account_email)}
  end

  describe "trial 2 day notice with valid token" do
    before do
      params =  {id: 1, :data => {:object => {:customer => "test_token"}}}
      MonitorMailer.stub trial_2day_notice: double(deliver!:true,deliver:true)
      post :webhook_trial_2day_notice, params
    end

    it "should response with 200" do
      response.should have_http_status(200)
    end

    specify { MonitorMailer.should have_received(:trial_2day_notice)}
    specify { (organization.plan.name).should eq("Free Trial") }
  end # 2day notice

  describe "trial 2 day notice with invalid token" do
    before do
      params =  {id: 1, :data => {:object => {:customer => "wrong_token"}}}
      MonitorMailer.stub trial_2day_notice: double(deliver!:true,deliver:true)
      post :webhook_trial_2day_notice, params
    end

    it "should NOT responsed with 200" do
      response.should_not have_http_status(200)
    end

    specify { MonitorMailer.should_not have_received(:trial_2day_notice)}
    specify { (organization.plan.name).should eq("Free Trial") }
  end # 2day notice

  describe "final notice of trial ending with valid token" do

    before do
      params =  {id: 1, :data => {:object => {:customer => "test_token"}}}
      MonitorMailer.stub trial_final_notice: double(deliver!:true,deliver:true)
      Organization.any_instance.stub invoices: double(to_a: double(count:2))
      post :webhook_trial_ended, params
    end

    specify{ response.should have_http_status(200)}
    specify{ MonitorMailer.should have_received(:trial_final_notice)}
    specify { (organization.plan.name).should eq("Small") }
  end # final notice

  describe "final notice of trial ending with invalid token" do

    before do
      params =  {id: 1, :data => {:object => {:customer => "wrong_token"}}}
      MonitorMailer.stub trial_final_notice: double(deliver!:true,deliver:true)
      Organization.any_instance.stub invoices: double(to_a: double(count:2))
      post :webhook_trial_ended, params
    end

    specify{ response.should_not have_http_status(200)}
    specify{ MonitorMailer.should_not have_received(:trial_final_notice)}
    specify { (organization.plan.name).should eq("Free Trial") }  #remain the same
  end # final notice

end
