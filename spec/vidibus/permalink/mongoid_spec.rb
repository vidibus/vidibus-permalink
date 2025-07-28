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
      expect(model).to be_invalid
      expect(model.errors[:permalink]).to eq(["can't be blank"])
    end
  end

  describe 'saving' do
    it 'should work if permalink belongs to a different record' do
      Permalink.create!(value: "john-malkovich", linkable: appointment)
      john.save!
      expect(john.permalink).to eq('john-malkovich-2')
    end
  end

  describe 'destroying' do
    it 'should trigger deleting of all permalink objects with linkable' do
      appointment.destroy
      expect(Permalink.count).to eq(0)
    end

    it 'should not delete permalink objects of other linkables' do
      john.save
      appointment.destroy
      expect(Permalink.count).to eq(1)
    end
  end

  describe '#permalink' do
    it 'should set permalink attribute before validation' do
      john.valid?
      expect(john.permalink).to eq('john-malkovich')
    end

    it 'should persist the permalink' do
      john.save
      john = Model.first
      expect(john.permalink).to eq('john-malkovich')
    end

    it 'should create a permalink object from given attribute after
      creation' do
      john.save
      permalink = Permalink.first
      expect(permalink.value).to eq('john-malkovich')
    end

    it 'should not store a new permalink object unless attribute value did
      change' do
      john.save
      john.save
      expect(Permalink.count).to eq(1)
    end

    it 'should store a new permalink if attributes change' do
      john.save
      john.update_attributes(name: 'Inkognito')
      expect(john.reload.permalink).to eq('inkognito')
    end

    it 'should store a new permalink object if permalink changes' do
      john.save
      john.update_attributes(:name => 'Inkognito')
      permalinks = Permalink.all.to_a
      expect(permalinks.count).to eq(2)
      expect(permalinks.last.value).to eq('inkognito')
      expect(permalinks.last.current?).to eq(true)
    end

    it 'should should set a former permalink object as current if possible' do
      john.save
      john.update_attributes(name: 'Inkognito')
      john.update_attributes(name: 'John Malkovich')
      permalinks = Permalink.all.to_a
      expect(permalinks.count).to eq(2)
      expect(permalinks.first.current?).to eq(true)
    end

    it 'should accept multiple attributes' do
      expect(appointment.permalink).to eq('lunch-bistro')
    end

    it 'should be updatable' do
      appointment.update_attributes(reason: 'Drinking')
      expect(appointment.permalink).to eq('drinking-bistro')
    end

    it 'should work with a method as permalink attribute' do
      expect(house.permalink).to eq('hello-you')
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
        expect(john.permalink).to eq('john-malkovich')
      end

      it 'should not be stored as permalink object when :repository option
        is set to false' do
        Model.create(name: 'John Malkovich')
        expect(Permalink.count).to eq(0)
      end

      it 'should be unique for model' do
        skip 'Allow incrementation for class that serves as repository.'
        Model.create(name: 'John Malkovich')
        john = Model.create(name: 'John Malkovich')
        expect(john.permalink).to_not eq('john-malkovich')
      end
    end
  end

  describe '#permalink_object' do
    it 'should return the current permalink object' do
      appointment.update_attributes(reason: 'Drinking')
      permalink = appointment.permalink_object
      expect(permalink.class).to eq(Permalink)
      expect(permalink.value).to eq(appointment.permalink)
      expect(permalink.current?).to eq(true)
    end

    it 'should return the permalink object assigned recently' do
      appointment.reason = 'Drinking'
      appointment.valid?
      expect(appointment.permalink_object.new_record?).to eq(true)
    end
  end

  describe '#permalink_scope' do
    it 'should return the current permalink scope' do
      class ModelWithScope < Model
        permalink :name, scope: {'realm' => 'rugby'}
      end
      bob = ModelWithScope.new(name: 'Bob Smith')
      expect(bob.permalink_scope).to eq({'realm' => 'rugby'})
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
      expect(bob.permalink_scope).to eq({
        'realm' => 'hockey',
        'category' => 'sport'
      })
    end

    it 'should raise an error if the scope value is invalid' do
      class ModelWithScope < Model
        permalink :name, scope: {'realm' => :realm}
      end

      bob = ModelWithScope.new(name: 'Bob Smith')
      expect { bob.permalink_scope }.to raise_error(Vidibus::Permalink::Mongoid::PermalinkConfigurationError)
    end
  end

  describe '#permalink_objects' do
    it 'should return all permalink objects ordered by time of update' do
      stub_time!('04.11.2010')
      appointment.update_attributes(reason: 'Drinking')
      stub_time!('05.11.2010')
      appointment.update_attributes(reason: 'Lunch')
      permalinks = appointment.permalink_objects
      expect(permalinks[0].value).to eq('drinking-bistro')
      expect(permalinks[1].value).to eq('lunch-bistro')
    end

    it 'should only return permalink objects assigned to the current
      linkable' do
      john.save
      expect(appointment.permalink_objects.count).to eq(1)
    end
  end

  describe '#permalink_repository' do
    it 'should default to Vidibus::Permalink' do
      Car.permalink(:whatever)
      expect(Car.new.permalink_repository).to eq(Permalink)
    end

    it 'should be nil if :repository option is set to false' do
      Car.permalink(:whatever, repository: false)
      expect(Car.new.permalink_repository).to eq(nil)
    end
  end

  describe '#static_permalink' do
    it 'should be nil before validation' do
      expect(john.static_permalink).to eq(nil)
    end

    it 'should be set from permalink' do
      john.valid?
      expect(john.static_permalink).to eq('john-malkovich')
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
          expect(john.static_permalink).to eq('john-malkovich')
        end
      end

      context 'if record is new' do
        it 'should change when permalink is changed' do
          john.name = 'Peter Pan'
          john.valid?
          expect(john.static_permalink).to eq('peter-pan')
        end
      end
    end
  end

  describe '.permalink' do
    it 'should set .permalink_attributes' do
      Car.permalink(:whatever, :it, :takes)
      expect(Car.permalink_attributes).to eq([:whatever, :it, :takes])
    end

    it 'should set .permalink_options' do
      Car.permalink(:whatever, :it, :takes, repository: false)
      expect(Car.permalink_options).to eq({repository: false})
    end
  end
end
