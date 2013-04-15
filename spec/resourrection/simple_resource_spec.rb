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
    
    let(:model){
        Class.new(Sequel::Model(:models)){
            set_schema{
                primary_key :id
                string :title
            }
        }
    }
    before{
        model.create_table!
    }

    describe 'basics' do
        before{
            m = model
            
            app.instance_eval do
                resourrect 'models', model: m
            end
        }

        describe 'collection' do
            let(:url){'/models.json'}
            
            describe 'GET' do
                let!(:list){
                    (1..5).map{|i| model.create(title: "model-#{i}")}
                }
                subject{
                    response_of_get url
                }

                it{should be_successful}
                its(:json){should be_kind_of(Array)}
                its(:json){should =~ JSON.parse(list.to_json)}
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
                    its(:keys){should include(*model.columns.map(&:to_s))}
                    its(['title']){should == data[:title]}
                end
            end
        end

        describe 'single resource' do
            let(:object){model.create(title: 'object')}
            let(:url){"/models/#{object.id}.json"}
            
            describe 'GET' do
                subject{response_of_get url}
                it{should be_successful}
                its(:body){should == object.to_json}

                context "when no object found" do
                    let(:url){"/models/#{object.id + 1_000}.json"}
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
                    model.find(id: object.id).should be_nil
                }
            end
        end
    end
end
