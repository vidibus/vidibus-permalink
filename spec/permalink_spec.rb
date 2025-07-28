require "spec_helper"

describe "Permalink" do
  let(:asset) { Asset.create!(label: "Something")}
  let(:category) { Category.create!(label: "Else")}
  let(:this) { Permalink.create!(value: "Hey Joe!", linkable: asset)}
  let(:another) { Permalink.create!(value: "Something", linkable: asset)}

  def create_permalink(options = {})
    options[:value] ||= "Super Trouper"
    options[:linkable] ||= asset
    Permalink.create!(options)
  end

  def stub_stopwords(list)
    I18n.backend.store_translations :en, vidibus: {stopwords: list}
  end

  describe "validation" do
    it "should pass with valid attributes" do
      expect(this).to be_valid
    end

    it "should fail without a value" do
      this.value = nil
      expect(this).to be_invalid
    end
  end

  describe "creating" do
    it "should set current on the latest permalink and unset current on all other permalinks of the assigned linkable" do
      first = create_permalink
      second = create_permalink
      third = create_permalink
      expect(first.reload.current?).to eq(false)
      expect(second.reload.current?).to eq(false)
      expect(third.reload.current?).to eq(true)
    end

    it "should not affect permalinks of other linkables" do
      this
      another = Permalink.create!(value: "Buh!", linkable: category)
      expect(another.current?).to eq(true)
      expect(this.reload.current?).to eq(true)
    end

    it "should not affect permalinks in different scopes" do
      this
      another = Permalink.create!({
        value: "Buh!", linkable: asset, scope: {realm: "rubgy"}
      })
      expect(another.current?).to eq(true)
      expect(this.reload.current?).to eq(true)
    end
  end

  describe "updating" do
    it "should unset current on all other permalinks of the assigned linkable if the current permalink is current" do
      first = create_permalink
      second = create_permalink
      third = create_permalink
      first.reload # This is important! Caching will hurt you!

      first.current!
      first.save
      expect(first.reload.current?).to eq(true)
      expect(second.reload.current?).to eq(false)
      expect(third.reload.current?).to eq(false)
    end
  end

  describe "deleting" do
    let(:last) { Permalink.create!(value: "Buh!", linkable: asset) }

    before do
      stub_time!("04.11.2010")
      this
      stub_time!("05.11.2010")
      another
    end

    it "should not affect other permalinks of the same linkable unless the deleted permalink was the current one" do
      expect(this.reload.destroy).to eq(true)
      expect(another.reload.current?).to eq(true)
    end

    it "should set the lastly updated permalink as current if the deleted permalink was the current one" do
      expect(last.destroy).to eq(true)
      expect(another.reload.current?).to eq(true)
    end

    it "should not affect other permalinks but the last one if the deleted permalink was the current one" do
      expect(last.destroy).to eq(true)
      expect(this.reload.current?).to eq(false)
    end
  end

  describe "#scope=" do
    let(:this) { Permalink.new }

    it "should convert the scope to an array" do
      this.scope = {"realm" => "rugby"}
      expect(this.scope).to eq(["realm:rugby"])
    end
  end

  describe "#linkable" do
    it "should fetch the linkable object" do
      expect(this.linkable).to eq(asset)
    end

    it "should return nil if no linkable has been set" do
      this.linkable = nil
      expect(this.linkable).to eq(nil)
    end
  end

  describe "#sanitize_value!" do
    it "should sanitized the value" do
      this.value = "Hey Joe!"
      this.sanitize_value!
      expect(this.value).to eq("hey-joe")
    end

    it "should increment the value" do
      create_permalink(:value => "Hey Joe!")
      this.sanitize_value!
      expect(this.value).to eq("hey-joe-2")
    end

    it "should re-use permalinks as they become available again" do
      this
      create_permalink(:value => "Hey Joe!")
      this.destroy
      other = create_permalink(:value => "Hey Joe!")
      expect(other.value).to eq("hey-joe")
    end

    it "should be called before validation" do
      mock(this).sanitize_value!
      this.valid?
    end

    context "with stop words" do
      before {stub_stopwords(%w[its a])}

      it "should be cleaned from stop words before validation" do
        this.value = "It's a beautiful day."
        this.sanitize_value!
        expect(this.value).to eq("beautiful-day")
      end

      it "should not be cleaned from stop words if the resulting value would be empty" do
        this.value = "It's a..."
        this.sanitize_value!
        expect(this.value).to eq("it-s-a")
      end

      it "should not be cleaned from stop words if the resulting value already exists" do
        Permalink.create!(value: "It's a beautiful day.", linkable: asset)
        this = Permalink.new(value: "It's a beautiful day.")
        this.sanitize_value!
        expect(this.value).to eq("it-s-a-beautiful-day")
      end
    end

    describe "incrementation" do
      it "should be performed unless value is unique" do
        this.value = another.value
        expect(this.save).to eq(true)
        expect(this.value).to_not eq(another.value)
      end

      it "should not be performed unless value did change" do
        this.update_attributes(value: "It's a beautiful day.")
        dont_allow(this).increment
        this.value = "It's a beautiful day."
      end

      it "should append 2 as first number" do
        first = create_permalink
        expect(create_permalink.value).to eq("super-trouper-2")
      end

      it "should append 3 if 2 is already taken" do
        create_permalink
        create_permalink
        expect(create_permalink.value).to eq("super-trouper-3")
      end

      it "should append 2 if 3 is taken but 2 has been deleted" do
        create_permalink
        second = create_permalink
        create_permalink
        second.reload.destroy
        expect(create_permalink.value).to eq("super-trouper-2")
      end

      it "should not increase because of different scopes" do
        create_permalink(scope: {"realm" => "rugby"})
        link = create_permalink(scope: {"realm" => "hockey"})
        expect(link.value).to eq("super-trouper")
      end
    end
  end

  describe "#current?" do
    it "should be true by default" do
      expect(this.current?).to eq(true)
    end

    it "should return true if _current is true" do
      this._current = true
      expect(this.current?).to eq(true)
    end

    it "should return false unless _current is true" do
      this._current = false
      expect(this.current?).to eq(false)
    end
  end

  describe "#current!" do
    it "should set _current to true" do
      this.current!
      expect(this._current).to eq(true)
    end
  end

  describe "#current" do
    before {this; another}

    it "should return self for the current permalink" do
      expect(another.reload.current).to eq(another)
    end

    it "should return the current permalink of the given linkable" do
      expect(this.reload.current).to eq(another)
    end
  end

  describe ".for_value" do
    it "should return finder conditions to retreive permalinks for the given value" do
      this; another
      expect(Permalink.for_value("Hey Joe!").to_a).to eq([this])
    end

    it 'should select incremented permalinks' do
      link = Permalink.create!(value: "hey-joe-2", linkable: asset)
      expect(Permalink.for_value("Hey Joe!").to_a).to eq([link])
    end

    it 'should select permalinks with stopwords' do
      stub_stopwords(%w[for the])
      I18n.locale = :en
      link = Permalink.create!(value: "joe-for-the-win", linkable: asset)
      expect(Permalink.for_value("Joe for the win!").to_a).to eq([link])
    end

    it 'should not sanitize input if `false` is given as argument' do
      criteria = Permalink.for_value("Hey Joe!", false)
      expect(criteria.class).to eq(Mongoid::Criteria)
      expect(criteria.selector['value']).to match('Hey Joe!')
    end
  end

  describe ".for_linkable" do
    it "should return finder conditions to retreive permalinks for the given object" do
      this
      Permalink.create!(value: "Buh!", linkable: category)
      expect(Permalink.for_linkable(asset).to_a).to eq([this])
    end
  end

  describe ".for_scope" do
    it "should find objects within the given scope" do
      this
      scope = {"realm" => "rugby"}
      other = Permalink.create!({
        value: "Hey Bob!", scope: scope, linkable: asset
      })
      expect(Permalink.for_scope(scope).to_a).to eq([other])
    end
  end

  describe ".dispatch" do
    it "should return a Vidibus::Permalink::Dispatcher object" do
      expect(Permalink.dispatch("/something").class).
        to eq(Vidibus::Permalink::Dispatcher)
    end
  end

  describe ".sanitize" do
    before {stub_stopwords(%w[its a])}

    it "should return a sanitized string without stopwords" do
      Permalink.sanitize("It's a beautiful day.").should eq("beautiful-day")
    end
  end

  describe ".scope_list" do
    it "should convert a scope hash" do
      scope = {"realm" => "rugby"}
      expect(Permalink.scope_list(scope)).to eq(["realm:rugby"])
    end

    it "should not convert an array twice" do
      scope = ["realm:rugby"]
      expect(Permalink.scope_list(scope)).to eq(scope)
    end
  end
end
