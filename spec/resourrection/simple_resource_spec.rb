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
                    post_json url, model: data
                }

                subject{last_response}
                it{should be_successful}
                its(:status){should == 201}

                describe 'headers' do
                    let(:id){last_response.json['id']}
                    subject{last_response.headers}
                    its(['Location']){should == "/models/#{id}.json"}
                end

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
                    put_json url, model: {title: 'changed'}
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
                    patch_json url, model: {title: 'changed'}
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

    describe 'with associations' do
        let(:author){
            Class.new(Sequel::Model(:authors)){
                set_schema{
                    primary_key :id
                    string :name
                }
            }
        }
        let(:text){
            Class.new(Sequel::Model(:texts)){
                set_schema{
                    primary_key :id
                    foreign_key :author_id
                    string :title
                }
            }
        }
        before{
            text.create_table!
            author.create_table!
            author.one_to_many :texts, class: text, key: :author_id
            text.many_to_one :author, class: author, key: :author_id

            t = text
            
            app.instance_eval do
                resourrect 'texts', model: t
            end
        }

        describe 'POST' do
            context 'when author exists' do
                let!(:existing_author){author.create(name: 'vasya')}

                let(:response){
                    response_of_post '/texts.json', text: {title: 'blah', author: {id: existing_author.id}}
                }

                let(:created_id){response.json['id']}

                subject{text[created_id]}

                its(:author){should == existing_author}
            end
            
            context 'when new author' do
                let(:response){
                    response_of_post '/texts.json', text: {title: 'blah', author: {name: 'vasya'}}
                }

                let(:created_id){response.json['id']}

                subject{text[created_id].author}

                it{should_not be_nil}
                its(:name){should == 'vasya'}
            end
        end
    end
end
