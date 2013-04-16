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

        let(:response){response_of_get url, params}

        before{
            m = model
            
            app.instance_eval do
                resourrect 'models', model: m do
                    paged 'page', 'pagesize', default: 2
                end
            end
        }
        describe 'default page' do
            let(:params){ {} }
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

                its(['content']){should be_kind_of(Array)}
                its(['content']){should have(2).items}
                its(['content']){should == JSON.parse(model.limit(2).all.to_json)}
            end
        end

        describe 'first page' do
            let(:params){ {page: 1} }
            subject{response.json}
            
            its(['pager']){should == {
                'page' => 1,
                'next' => 2,
                'total' => (list.size/2.0).ceil
            }}

            its(['content']){should have(2).items}
            its(['content']){should == JSON.parse(model.limit(2).all.to_json)}
        end

        describe 'next page' do
            let(:params){ {page: 2} }
            subject{response.json}

            its(['pager']){should == {
                'page' => 2,
                'next' => 3,
                'total' => (list.size/2.0).ceil
            }}

            its(['content']){should have(2).items}
            its(['content']){should == JSON.parse(model.limit(2, 2).all.to_json)}
        end

        describe 'last page' do
            let(:params){ {page: 3} }
            subject{response.json}

            its(['pager']){should == {
                'page' => 3,
                'next' => nil,
                'total' => (list.size/2.0).ceil
            }}

            its(['content']){should have(1).items}
            its(['content']){should == JSON.parse(model.limit(2, 4).all.to_json)}
        end

        describe 'changed pagesize' do
            let(:params){ {page: 1, pagesize: 10} }
            subject{response.json}
            
            it{should be_kind_of(Hash)}
            its(:keys){should =~ %w[content pager]}
            its(['pager']){should == {
                'page' => 1,
                'next' => nil,
                'total' => (list.size/10.0).ceil
            }}

            its(['content']){should be_kind_of(Array)}
            its(['content']){should have([list.size, 10].min).items}
        end
    end

    describe 'ordering' do
        let!(:list){
            (1..5).map{|i| model.create(title: "paged-#{5-i}")} # title natural order will be reversed
        }

        let(:response){response_of_get url, params}

        before{
            m = model
            
            app.instance_eval do
                resourrect 'models', model: m do
                    ordered 'order',
                        orders: {
                            'title' => :title,
                            'id' => :id
                        },
                        default: 'title'
                end
            end
        }

        describe 'default' do
            let(:params){ {} }
            subject{response.json}
            it{should be_sorted_by_key('title')}
        end

        describe 'reordered' do
            let(:params){ {'order' => 'id'} }
            subject{response.json}
            it{should be_sorted_by_key('id')}
        end

        describe 'asc/desc' do
            let(:params){ {'order' => '-title'} }
            subject{response.json}
            it{should be_reverse_sorted_by_key('title')}
        end
    end

    describe 'filtering' do
    end

end
