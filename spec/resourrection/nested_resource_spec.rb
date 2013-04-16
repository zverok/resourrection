describe Resourrection do
    before(:all){
        @database = Sequel.sqlite
    }

    let(:app){
        Class.new(Sinatra::Base){
            register Resourrection
            set :show_exceptions, false
            set :raise_errors, true
        }
    }
    
    let!(:model){
        Class.new(Sequel::Model(:models)){
            set_schema{
                primary_key :id
                string :title
            }
        }
    }
    let!(:child){
        Class.new(Sequel::Model(:children)){
            set_schema{
                primary_key :id
                foreign_key :parent_id
                string :title
            }

            many_to_one :parent, class: model, key: :parent_id
        }
    }

    before{
        model.create_table!
        child.create_table!
        model.one_to_many :children, class: child, key: :parent_id
    }

    let!(:base){model.create(title: 'base')}
    let!(:other){model.create(title: 'other')}

    describe 'nesting' do
        before{
            m = model
            
            app.instance_eval do
                resourrect 'models', model: m do
                    resourrect 'children', association: :children
                end
            end
        }

        describe 'collection' do
            let(:url){"/models/#{base.id}/children.json"}
            
            describe 'GET' do
                let!(:list){
                    (1..5).map{|i| child.create(parent: base, title: "child-#{i}")}
                }
                let!(:others_list){
                    (1..5).map{|i| child.create(parent: other, title: "not a child-#{i}")}
                }
                subject{
                    response_of_get url
                }

                it{should be_successful}
                its(:json){should be_kind_of(Array)}
                its(:json){should =~ JSON.parse(list.to_json)}

                context "when wrong parent" do
                    let(:url){"/models/#{base.id + 10_000}/children.json"}

                    it{should_not be_successful}
                    its(:status){should == 404}
                end
            end

            describe 'POST' do
                let(:data){ {title: 'created'} }
                
                before{
                    post_json url, data
                }

                subject{last_response}
                it{should be_successful}
                its(:status){should == 201}

                describe 'response' do
                    subject{last_response.json}
                    it{should be_kind_of(Hash)}
                    its(['title']){should == data[:title]}
                    its(['parent_id']){should == base.id}
                end
            end

        end

        describe 'single resource' do
            let(:object){child.create(title: 'object', parent: base)}
            let(:url){"/models/#{base.id}/children/#{object.id}.json"}

            describe 'GET' do
                subject{response_of_get url}
                it{should be_successful}
                its(:body){should == object.to_json}

                context "when no base found" do
                    let(:url){"/models/#{base.id + 1_000}/children/#{object.id}.json"}
                    it{should_not be_successful}
                    its(:status){should == 404}
                end

                context "when no object found" do
                    let(:url){"/models/#{base.id}/children/#{object.id + 1_000}.json"}
                    it{should_not be_successful}
                    its(:status){should == 404}
                end
            end

            describe 'PUT' do
                before{
                    put_json url, {title: 'changed'}
                }
                
                subject{
                    last_response
                }

                it{should be_successful}
                
                describe "changed object" do
                    subject{object.tap(&:reload)}
                    
                    its(:title){should == 'changed'}
                end
            end

            describe 'PATCH' do
                before{
                    patch_json url, {title: 'changed'}
                }
                
                subject{
                    last_response
                }

                it{should be_successful}
                
                describe "changed object" do
                    subject{object.tap(&:reload)}
                    
                    its(:title){should == 'changed'}
                end
            end

            describe 'DELETE' do
                before{
                    delete url
                }
                subject{
                    last_response
                }
                it{should be_successful}
                
                specify{
                    child.find(id: object.id).should be_nil
                }
            end
        end
    end

    context 'when we need to go deeper' do
        let(:grandchild){
            Class.new(Sequel::Model(:grandchildren)){
                set_schema{
                    primary_key :id
                    foreign_key :parent_id
                    string :title
                }
            }
        }

        before{
            grandchild.create_table!
            child.one_to_many :grandchildren, class: grandchild, key: :parent_id
            grandchild.many_to_one :parent, class: child, key: :parent_id

            m = model
            
            app.instance_eval do
                resourrect 'models', model: m do
                    resourrect 'children', association: :children do
                        resourrect 'grandchildren', association: :grandchildren
                    end
                end
            end
        }

        let(:base_child){child.create(parent: base, title: 'base child')}
        let(:other_child){child.create(parent: base, title: 'other child')}

        describe 'collection' do
            let(:url){"/models/#{base.id}/children/#{base_child.id}/grandchildren.json"}
            
            describe 'GET' do
                let!(:gclist){
                    (1..5).map{|i| grandchild.create(parent: base_child, title: "grandchild-#{i}")}
                }
                let!(:others_gclist){
                    (1..5).map{|i| grandchild.create(parent: other_child, title: "not a grandchild-#{i}")}
                }
                subject{
                    response_of_get url
                }

                it{should be_successful}
                its(:json){should be_kind_of(Array)}
                its(:json){should =~ JSON.parse(gclist.to_json)}

                context "when wrong granny" do
                    let(:url){"/models/#{base.id + 10_000}/children/#{base_child.id}.json"}

                    it{should_not be_successful}
                    its(:status){should == 404}
                end

                context "when wrong parent" do
                    let(:url){"/models/#{base.id}/children/#{base_child.id + 10_000}.json"}

                    it{should_not be_successful}
                    its(:status){should == 404}
                end
            end
        end
    end
end
