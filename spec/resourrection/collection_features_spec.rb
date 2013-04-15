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

    let(:url){'/models.json'}

    describe 'paging' do
        let!(:list){
            (1..5).map{|i| model.create(title: "paged-#{i}")}
        }

        before{
            m = model
            
            app.instance_eval do
                resourrect 'models', model: m do
                    paged 'page', 'pagesize', default: 2
                end
            end
        }
        describe 'default page' do
            let(:response){response_of_get url}
            subject{response}
            it{should be_successful}

            describe 'data' do
                subject{response.json}
                it{should be_kind_of(Hash)}
                its(:keys){should =~ %w[content pager]}
                its(['pager']){should == {
                    'page' => 1,
                    'next' => 2,
                    'total' => (list.size/2.0).ceil
                }}
            end
        end

        #describe 'first page' do
            #subject{response_of_get url, page: 1}
        #end

        #describe 'next page' do
            #subject{response_of_get url, page: 2}
        #end

        #describe 'changed pagesize' do
            #subject{response_of_get url, page: 1, pagesize: 10}
        #end
    end

    describe 'ordering' do
    end

    describe 'filtering' do
    end

end
