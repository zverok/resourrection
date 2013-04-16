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

        let(:response){response_of_get url, params}

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
        let!(:list){
            (1..5).map{|i| model.create(title: "model-#{i}")}
        }

        before{
            m = model
            
            app.instance_eval do
                resourrect 'models', model: m do
                    filtered 'filters' do
                        on('title'){|dataset, filter| dataset.where(title: filter)}
                        on('title_in', :array){|dataset, filter| dataset.where(title: filter)}

                        on('title_include', :like){|dataset, filter| dataset.where(:title.like(filter))}

                        on('title_after'){|dataset, filter| dataset.where{|r| r.title >= filter} }
                    end
                end
            end
        }

        shared_context 'filter checker' do
            let(:from_db){model.filter(database_filter)}
            let(:from_api){response_of_get(url, :filters => api_filter).json}

            specify{
                from_api.should =~ JSON.parse(from_db.to_json)
            }
        end

        describe 'plain filter' do
            let(:database_filter){ {title: 'model-3'} }
            let(:api_filter){ {title: 'model-3'} }

            include_context 'filter checker'
        end

        describe 'list filter' do
            let(:database_filter){ {title: ['model-3', 'model-5']} }
            let(:api_filter){ {title_in: 'model-3,model-5'} }

            include_context 'filter checker'
        end

        describe 'like filter' do
            let(:database_filter){ :title.like('%odel%') }
            let(:api_filter){ {title_include: 'odel'} }

            include_context 'filter checker'
        end

        describe 'more filter' do
            let(:database_filter){ Sequel.expr(:title) >= 'model-3' }
            let(:api_filter){ {title_after: 'model-3'} }

            include_context 'filter checker'
        end
    end

    describe 'dataset adjusting' do
        let!(:list){
            (1..5).map{|i| model.create(title: "model-#{i}")}
        }

        before{
            m = model
            
            app.instance_eval do
                resourrect 'models', model: m do
                    adjusted{|dataset|
                        dataset.exclude(title: 'model-3')
                    }
                end
            end
        }

        let(:from_db){model.exclude(title: 'model-3')}
        let(:from_api){response_of_get(url).json}

        specify{
            from_api.should =~ JSON.parse(from_db.to_json)
        }
    end
end
