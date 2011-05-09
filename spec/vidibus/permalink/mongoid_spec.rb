require "spec_helper"

class Base
  include Mongoid::Document
  include Vidibus::Uuid::Mongoid
  include Vidibus::Permalink::Mongoid
end

class Model < Base
  field :name
  permalink :name
end

class Appointment < Base
  field :reason
  field :location
  permalink :reason, :location
end

class Car < Base
  field :make
end

describe "Vidibus::Permalink::Mongoid" do

  let(:john) {Model.new(:name => "John Malkovich")}
  let(:appointment) {Appointment.create(:location => "Bistro", :reason => "Lunch")}

  describe "validation" do
    it "should fail if permalink is blank" do
      model = Model.new(:permalink => "")
      model.should be_invalid
      model.errors[:permalink].should have(1).error
    end
  end

  describe "destroying" do
    it "should trigger deleting of all permalink objects with linkable" do
      appointment.destroy
      Permalink.all.to_a.should have(:no).permalinks
    end

    it "should not delete permalink objects of other linkables" do
      john.save
      appointment.destroy
      Permalink.all.to_a.should have(1).permalink
    end
  end

  describe "#permalink" do
    it "should set permalink attribute before validation" do
      john.valid?
      john.permalink.should eql("john-malkovich")
    end

    it "should persist the permalink" do
      john.save
      john = Model.first
      john.permalink.should eql("john-malkovich")
    end

    it "should create a permalink object from given attribute after creation" do
      john.save
      permalink = Permalink.first
      permalink.value.should eql("john-malkovich")
    end

    it "should not store a new permalink object unless attribute value did change" do
      john.save
      john.save
      Permalink.all.to_a.should have(1).object
    end

    it "should store a new permalink if attributes change" do
      john.save
      john.update_attributes(:name => "Inkognito")
      john.reload.permalink.should eql("inkognito")
    end

    it "should store a new permalink object if permalink changes" do
      john.save
      john.update_attributes(:name => "Inkognito")
      permalinks = Permalink.all.to_a
      permalinks.should have(2).permalinks
      permalinks.last.value.should eql("inkognito")
      permalinks.last.should be_current
    end

    it "should should set a former permalink object as current if possible" do
      john.save
      john.update_attributes(:name => "Inkognito")
      john.update_attributes(:name => "John Malkovich")
      permalinks = Permalink.all.to_a
      permalinks.should have(2).objects
      permalinks.first.should be_current
    end

    it "should accept multiple attributes" do
      appointment.permalink.should eql("lunch-bistro")
    end

    it "should be updatable" do
      appointment.update_attributes(:reason => "Drinking")
      appointment.permalink.should eql("drinking-bistro")
    end

    it "should raise an error unless permalink attributes have been defined" do
      expect {Car.create(:make => "Porsche")}.to raise_error(Car::PermalinkConfigurationError)
    end

    context "with :repository option set to false" do
      before {Model.permalink(:name, :repository => false)}

      it "should be proper" do
        john = Model.create(:name => "John Malkovich")
        john.permalink.should eql("john-malkovich")
      end

      it "should not be stored as permalink object when :repository option is set to false" do
        Model.create(:name => "John Malkovich")
        Permalink.all.should be_empty
      end

      it "should be unique for model" do
        pending "Allow incrementation for class that serves as repository."
        Model.create(:name => "John Malkovich")
        john = Model.create(:name => "John Malkovich")
        john.permalink.should_not eql("john-malkovich")
      end
    end
  end

  describe "#permalink_object" do
    it "should return the current permalink object" do
      appointment.update_attributes(:reason => "Drinking")
      permalink = appointment.permalink_object
      permalink.should be_a(Permalink)
      permalink.value.should eql(appointment.permalink)
      permalink.should be_current
    end

    it "should return the permalink object assigned recently" do
      appointment.reason = "Drinking"
      appointment.valid?
      appointment.permalink_object.should be_a_new_record
    end
  end

  describe "#permalink_objects" do
    it "should return all permalink objects ordered by time of update" do
      stub_time!("04.11.2010")
      appointment.update_attributes(:reason => "Drinking")
      stub_time!("05.11.2010")
      appointment.update_attributes(:reason => "Lunch")
      permalinks = appointment.permalink_objects
      permalinks[0].value.should eql("drinking-bistro")
      permalinks[1].value.should eql("lunch-bistro")
    end

    it "should only return permalink objects assigned to the current linkable" do
      john.save
      appointment.permalink_objects.to_a.should have(1).permalink
    end
  end

  describe "#permalink_repository" do
    it "should default to Vidibus::Permalink" do
      Car.permalink(:whatever)
      Car.new.permalink_repository.should eql(Permalink)
    end

    it "should be nil if :repository option is set to false" do
      Car.permalink(:whatever, :repository => false)
      Car.new.permalink_repository.should be_nil
    end
  end

  describe ".permalink" do
    it "should set .permalink_attributes" do
      Car.permalink(:whatever, :it, :takes)
      Car.permalink_attributes.should eql([:whatever, :it, :takes])
    end

    it "should set .permalink_options" do
      Car.permalink(:whatever, :it, :takes, :repository => false)
      Car.permalink_options.should eql({:repository => false})
    end
  end
end
