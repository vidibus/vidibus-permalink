require "spec_helper"

describe "Vidibus::Permalink::Dispatcher" do
  describe "Dispatcher" do
    let(:category) { Category.create! }
    let(:asset) { Asset.create! }
    let(:category_permalink) do
      Permalink.create!(value: "Something", linkable: category)
    end
    let(:asset_permalink) do
      Permalink.create!(value: "Pretty", linkable: asset)
    end
    let(:this) { Vidibus::Permalink::Dispatcher.new("/something/pretty") }

    describe "initializing" do
      it "should require a path" do
        expect {Vidibus::Permalink::Dispatcher.new}.to raise_error(ArgumentError)
      end

      it "should require an absolute request path" do
        expect {Vidibus::Permalink::Dispatcher.new("something/pretty")}.
          to raise_error(Vidibus::Permalink::Dispatcher::PathError)
      end

      it "should accept an absolute request path" do
        expect(this).to be_a(Vidibus::Permalink::Dispatcher)
      end
    end

    describe "#path" do
      it "should return the given request path" do
        expect(this.path).to eq("/something/pretty")
      end
    end

    describe "#path=" do
      it "should set the request path" do
        this.path = "/something/nasty"
        expect(this.path).to eq("/something/nasty")
      end
    end

    describe "#parts" do
      it "should contain the parts of the given path" do
        expect(this.parts).to eq(%w[something pretty])
      end

      it "should deal with empty parts of path" do
        this.path = "/something//pretty"
        expect(this.parts).to eq(%w[something pretty])
      end

      it "should ignore params" do
        this.path = "/something/pretty?hello=world"
        expect(this.parts).to eq(%w[something pretty])
      end

      it "should ignore file extension" do
        this.path = "/something/pretty?hello=world"
        expect(this.parts).to eq(%w[something pretty])
      end
    end

    describe "#objects" do
      before do
        category_permalink
        asset_permalink
      end

      it "should contain all permalinks of given path" do
        expect(this.objects).to eq([category_permalink, asset_permalink])
      end

      it "should reflect the order of the parts in request path" do
        this = Vidibus::Permalink::Dispatcher.new("/pretty/something")
        expect(this.objects).to eq([asset_permalink, category_permalink])
      end

      it "should contain empty records for unresolvable parts of the path" do
        this = Vidibus::Permalink::Dispatcher.new("/some/pretty")
        expect(this.objects).to eq([nil, asset_permalink])
      end

      it "should not contain more than one permalink per linkable" do
        Permalink.create!(value: "New", linkable: asset)
        this = Vidibus::Permalink::Dispatcher.new("/pretty/new")
        expect(this.objects).to eq([asset_permalink, nil])
      end

      it "should only contain records within the same scope" do
        scope = {"realm" => "rugby"}
        subject = Permalink.create!({
          value: "New", scope: scope, linkable: asset
        })
        other = Permalink.create!({
          value: "New", scope: {"realm" => "hockey"}, linkable: asset
        })
        this = Vidibus::Permalink::Dispatcher.new("/new", scope: scope)
        expect(this.objects.compact).to eq([subject])
      end
    end

    describe "found?" do
      before do
        category_permalink
        asset_permalink
      end

      it "should return true if all parts of the request path could be resolved" do
        expect(this.found?).to eq(true)
      end

      it "should return false if any part of the request path could not be resolved" do
        this = Vidibus::Permalink::Dispatcher.new("/some/pretty")
        expect(this.found?).to eq(false)
      end
    end

    describe "#redirect?" do
      before do
        category_permalink
        asset_permalink
        Permalink.create!(value: "New", linkable: asset)
      end

      it "should return true if any part of the path is not current" do
        expect(this.redirect?).to eq(true)
      end

      it "should return false if all parts of the request path are current" do
        this = Vidibus::Permalink::Dispatcher.new("/something/new")
        expect(this.redirect?).to eq(false)
      end

      it "should return nil if path could not be resolved" do
        this = Vidibus::Permalink::Dispatcher.new("/something/ugly")
        expect(this.redirect?).to eq(nil)
      end
    end

    describe "#redirect_path" do
      before do
        category_permalink
        asset_permalink
        Permalink.create!(value: "New", linkable: asset)
      end

      it "should return the current request path" do
        this = Vidibus::Permalink::Dispatcher.new("/something/pretty")
        expect(this.redirect_path).to eq("/something/new")
      end

      it "should return nil if redirecting is not necessary" do
        this = Vidibus::Permalink::Dispatcher.new("/something/new")
        expect(this.redirect_path).to eq(nil)
      end

      it "should not raise an error if no current permalink object is present" do
        skip("this has to be solved!")
      end
    end
  end
end
