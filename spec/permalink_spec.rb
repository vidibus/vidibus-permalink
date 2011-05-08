require "spec_helper"

describe "Permalink" do
  let(:asset) {Asset.create!(:label => "Something")}
  let(:category) {Category.create!(:label => "Else")}
  let(:this) {Permalink.create!(:value => "Hey Joe!", :linkable => asset)}
  let(:another) {Permalink.create!(:value => "Something", :linkable => asset)}

  def create_permalink(options = {})
    options[:value] ||= "Super Trouper"
    options[:linkable] ||= asset
    Permalink.create!(options)
  end

  def stub_stopwords(list)
    I18n.backend.store_translations :en, :vidibus => {:stopwords => list}
  end

  describe "validation" do
    it "should pass with valid attributes" do
      this.should be_valid
    end

    it "should fail without a value" do
      this.value = nil
      this.should be_invalid
    end

    it "should fail without an UUID given on linkable" do
      asset.uuid = nil
      expect {this.linkable}.to raise_error(Permalink::UuidRequiredError)
    end

    it "should fail if linkable_uuid is invalid" do
      this.linkable_uuid = "something"
      this.should be_invalid
    end

    it "should fail if linkable_uuid is missing" do
      this.linkable_class = nil
      this.should be_invalid
    end
  end

  describe "deleting" do
    let(:last) {Permalink.create!(:value => "Buh!", :linkable => asset)}

    before do
      stub_time!("04.11.2010")
      this
      stub_time!("05.11.2010")
      another
    end

    it "should not affect other permalinks of the same linkable unless the deleted permalink was the current one" do
      this.reload.destroy.should be_true
      another.reload.current?.should be_true
    end

    it "should set the lastly updated permalink as current if the deleted permalink was the current one" do
      last.destroy.should be_true
      another.reload.current?.should be_true
    end

    it "should not affect other permalinks but the last one if the deleted permalink was the current one" do
      last.destroy.should be_true
      this.reload.current?.should be_false
    end
  end

  describe "#linkable=" do
    let(:this) { Permalink.new }

    it "should set linkable_uuid" do
      this.linkable = asset
      this.linkable_uuid.should eql(asset.uuid)
    end

    it "should set linkable_class" do
      this.linkable = asset
      this.linkable_class.should eql("Asset")
    end
  end

  describe "#linkable" do
    before {this.instance_variable_set("@linkable", nil)}

    it "should fetch the linkable object" do
      this.linkable.should eql(asset)
    end

    it "should return nil if no linkable_class has been set" do
      this.linkable_class = nil
      this.linkable.should be_nil
    end

    it "should return nil if no linkable_uuid has been set" do
      this.linkable_uuid = nil
      this.linkable.should be_nil
    end
  end

  describe "#value" do
    it "should be sanitized when set" do
      this.value = "Hey Joe!"
      this.value.should eql("hey-joe")
    end

    context "with stop words" do
      before {stub_stopwords(%w[its a])}

      it "should be cleaned from stop words before validation" do
        this.value = "It's a beautiful day."
        this.value.should eql("beautiful-day")
      end

      it "should not be cleaned from stop words if the resulting value would be empty" do
        this.value = "It's a..."
        this.value.should eql("it-s-a")
      end

      it "should not be cleaned from stop words if the resulting value already exists" do
        Permalink.create!(:value => "It's a beautiful day.", :linkable => asset)
        this = Permalink.new(:value => "It's a beautiful day.")
        this.value.should eql("it-s-a-beautiful-day")
      end
    end

    describe "incrementation" do
      it "should be performed unless value is unique" do
        this.value = another.value
        this.save.should be_true
        this.value.should_not eql(another.value)
      end

      it "should not be performed unless value did change" do
        this.update_attributes(:value => "It's a beautiful day.")
        dont_allow(this).increment
        this.value = "It's a beautiful day."
      end

      it "should append 2 as first number" do
        first = create_permalink
        create_permalink.value.should eql("super-trouper-2")
      end

      it "should append 3 if 2 is already taken" do
        create_permalink
        create_permalink
        create_permalink.value.should eql("super-trouper-3")
      end

      it "should append 2 if 3 is taken but 2 has been deleted" do
        create_permalink
        second = create_permalink
        create_permalink
        second.reload.destroy
        create_permalink.value.should eql("super-trouper-2")
      end
    end
  end

  describe "#current?" do
    it "should return true after creation" do
      this.current?.should be_true
    end

    it "should return true after update" do
      another
      this.save
      this.reload.current?.should be_true
    end

    it "should return false on all other permalinks of the assigned linkable" do
      first = create_permalink
      second = create_permalink
      third = create_permalink
      first.reload.current?.should be_false
      second.reload.current?.should be_false
      third.reload.current?.should be_true
    end

    it "should not affect permalinks of other linkables" do
      this
      another = Permalink.create!(:value => "Buh!", :linkable => category)
      another.current?.should be_true
      this.reload.current?.should be_true
    end
  end

  describe "#current" do
    before {this; another}

    it "should return self for the current permalink" do
      another.reload.current.should eql(another)
    end

    it "should return the current permalink of the given linkable" do
      this.reload.current.should eql(another)
    end
  end

  describe ".for_value" do
    it "should return finder conditions to retreive permalinks for the given value" do
      this; another
      Permalink.for_value("Hey Joe!").to_a.should have(1).permalink
    end
  end

  describe ".for_linkable" do
    it "should return finder conditions to retreive permalinks for the given object" do
      this
      Permalink.create!(:value => "Buh!", :linkable => category)
      Permalink.for_linkable(asset).to_a.should have(1).permalink
    end
  end

  describe ".dispatch" do
    it "should return a Vidibus::Permalink::Dispatcher object" do
      Permalink.dispatch("/something").should be_a(Vidibus::Permalink::Dispatcher)
    end
  end

  describe ".sanitize" do
    before {stub_stopwords(%w[its a])}

    it "should return a sanitized string without stopwords" do
      Permalink.sanitize("It's a beautiful day.").should eql("beautiful-day")
    end
  end
end
