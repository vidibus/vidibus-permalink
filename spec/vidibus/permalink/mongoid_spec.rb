require 'spec_helper'

class Base
  include Mongoid::Document
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

class House < Base
  permalink :greeting

  def greeting
    'Hello you'
  end

  def greeting_changed?
    true
  end
end

describe 'Vidibus::Permalink::Mongoid' do
  let(:john) do
    Model.new(name: 'John Malkovich')
  end

  let(:appointment) do
    Appointment.create!(location: 'Bistro', reason: 'Lunch')
  end

  let(:house) do
    House.create!
  end

  describe 'validation' do
    it 'should fail if permalink is blank' do
      model = Model.new(permalink: '')
      model.should be_invalid
      model.errors[:permalink].should eq(["can't be blank"])
    end
  end

  describe 'saving' do
    it 'should work if permalink belongs to a different record' do
      Permalink.create!(value: "john-malkovich", linkable: appointment)
      john.save!
      john.permalink.should eq('john-malkovich-2')
    end
  end

  describe 'destroying' do
    it 'should trigger deleting of all permalink objects with linkable' do
      appointment.destroy
      Permalink.count.should eq(0)
    end

    it 'should not delete permalink objects of other linkables' do
      john.save
      appointment.destroy
      Permalink.count.should eq(1)
    end
  end

  describe '#permalink' do
    it 'should set permalink attribute before validation' do
      john.valid?
      john.permalink.should eq('john-malkovich')
    end

    it 'should persist the permalink' do
      john.save
      john = Model.first
      john.permalink.should eq('john-malkovich')
    end

    it 'should create a permalink object from given attribute after
      creation' do
      john.save
      permalink = Permalink.first
      permalink.value.should eq('john-malkovich')
    end

    it 'should not store a new permalink object unless attribute value did
      change' do
      john.save
      john.save
      Permalink.count.should eq(1)
    end

    it 'should store a new permalink if attributes change' do
      john.save
      john.update_attributes(name: 'Inkognito')
      john.reload.permalink.should eq('inkognito')
    end

    it 'should store a new permalink object if permalink changes' do
      john.save
      john.update_attributes(:name => 'Inkognito')
      permalinks = Permalink.all.to_a
      permalinks.count.should eq(2)
      permalinks.last.value.should eq('inkognito')
      permalinks.last.current?.should eq(true)
    end

    it 'should should set a former permalink object as current if possible' do
      john.save
      john.update_attributes(name: 'Inkognito')
      john.update_attributes(name: 'John Malkovich')
      permalinks = Permalink.all.to_a
      permalinks.count.should eq(2)
      permalinks.first.current?.should eq(true)
    end

    it 'should accept multiple attributes' do
      appointment.permalink.should eq('lunch-bistro')
    end

    it 'should be updatable' do
      appointment.update_attributes(reason: 'Drinking')
      appointment.permalink.should eq('drinking-bistro')
    end

    it 'should work with a method as permalink attribute' do
      house.permalink.should eq('hello-you')
    end

    it 'should raise an error unless permalink attributes have been
      defined' do
      expect {
        Car.create(make: 'Porsche')
      }.to raise_error(Car::PermalinkConfigurationError)
    end

    context 'with :repository option set to false' do
      before do
        Model.permalink(:name, :repository => false)
      end

      it 'should be proper' do
        john = Model.create(name: 'John Malkovich')
        john.permalink.should eq('john-malkovich')
      end

      it 'should not be stored as permalink object when :repository option
        is set to false' do
        Model.create(name: 'John Malkovich')
        Permalink.count.should eq(0)
      end

      it 'should be unique for model' do
        skip 'Allow incrementation for class that serves as repository.'
        Model.create(name: 'John Malkovich')
        john = Model.create(name: 'John Malkovich')
        john.permalink.should_not eq('john-malkovich')
      end
    end
  end

  describe '#permalink_object' do
    it 'should return the current permalink object' do
      appointment.update_attributes(reason: 'Drinking')
      permalink = appointment.permalink_object
      permalink.class.should eq(Permalink)
      permalink.value.should eq(appointment.permalink)
      permalink.current?.should eq(true)
    end

    it 'should return the permalink object assigned recently' do
      appointment.reason = 'Drinking'
      appointment.valid?
      appointment.permalink_object.new_record?.should eq(true)
    end
  end

  describe '#permalink_scope' do
    it 'should return the current permalink scope' do
      class ModelWithScope < Model
        permalink :name, scope: {'realm' => 'rugby'}
      end
      bob = ModelWithScope.new(name: 'Bob Smith')
      bob.permalink_scope.should eq({'realm' => 'rugby'})
    end

    it 'should perform and return the current permalink scope' do
      class ModelWithScope < Model
        def category; 'sport'; end
        permalink :name, scope: {
          'realm' => 'hockey',
          'category' => :category
      }
      end
      bob = ModelWithScope.new(name: 'Bob Smith')
      bob.permalink_scope.should eq({
        'realm' => 'hockey',
        'category' => 'sport'
      })
    end

    it 'should raise an error if the scope value is invalid' do
      class ModelWithScope < Model
        permalink :name, scope: {'realm' => :realm}
      end

      bob = ModelWithScope.new(name: 'Bob Smith')
      expect { bob.permalink_scope }.to raise_exception
    end
  end

  describe '#permalink_objects' do
    it 'should return all permalink objects ordered by time of update' do
      stub_time!('04.11.2010')
      appointment.update_attributes(reason: 'Drinking')
      stub_time!('05.11.2010')
      appointment.update_attributes(reason: 'Lunch')
      permalinks = appointment.permalink_objects
      permalinks[0].value.should eq('drinking-bistro')
      permalinks[1].value.should eq('lunch-bistro')
    end

    it 'should only return permalink objects assigned to the current
      linkable' do
      john.save
      appointment.permalink_objects.count.should eq(1)
    end
  end

  describe '#permalink_repository' do
    it 'should default to Vidibus::Permalink' do
      Car.permalink(:whatever)
      Car.new.permalink_repository.should eq(Permalink)
    end

    it 'should be nil if :repository option is set to false' do
      Car.permalink(:whatever, repository: false)
      Car.new.permalink_repository.should eq(nil)
    end
  end

  describe '#static_permalink' do
    it 'should be nil before validation' do
      john.static_permalink.should eq(nil)
    end

    it 'should be set from permalink' do
      john.valid?
      john.static_permalink.should eq('john-malkovich')
    end

    context 'with an existing permalink' do
      # before do
      #   john.valid?
      # end

      context 'if record is persisted' do
        before do
          john.save
        end

        it 'should not change when permalink is changed' do
          john.name = 'Peter Pan'
          john.valid?
          john.static_permalink.should eq('john-malkovich')
        end
      end

      context 'if record is new' do
        it 'should change when permalink is changed' do
          john.name = 'Peter Pan'
          john.valid?
          john.static_permalink.should eq('peter-pan')
        end
      end
    end
  end

  describe '.permalink' do
    it 'should set .permalink_attributes' do
      Car.permalink(:whatever, :it, :takes)
      Car.permalink_attributes.should eq([:whatever, :it, :takes])
    end

    it 'should set .permalink_options' do
      Car.permalink(:whatever, :it, :takes, repository: false)
      Car.permalink_options.should eq({repository: false})
    end
  end
end
