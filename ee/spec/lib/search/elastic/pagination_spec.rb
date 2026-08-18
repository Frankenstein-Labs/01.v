# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Pagination, feature_category: :global_search do
  include_context 'with filters shared context'

  let(:paginator) { described_class.new(query_hash) }

  before do
    query_hash[:sort] = { created_at: { order: :asc } }
  end

  describe 'without before and after' do
    describe '#first' do
      subject(:first_10_records_query) { paginator.first(10) }

      it 'generates the query without keyset pagination filters' do
        expect(first_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: []
            }
          },
          sort: [
            { created_at: { order: :asc } },
            { id: { order: :asc } }
          ],
          size: 10
        })
      end
    end

    describe '#last' do
      subject(:last_10_records_query) { paginator.last(10) }

      it 'generates the query without keyset pagination filters' do
        expect(last_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: []
            }
          },
          sort: [
            { created_at: { order: :desc } },
            { id: { order: :desc } }
          ],
          size: 10
        })
      end
    end
  end

  describe '#before' do
    before do
      paginator.before('2025-01-01', 1)
    end

    describe '#first' do
      subject(:first_10_records_query) { paginator.first(10) }

      it 'generates the query' do
        expect(first_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          created_at: { lt: '2025-01-01' }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                created_at: '2025-01-01'
                              }
                            },
                            {
                              range: {
                                id: { lt: 1 }
                              }
                            }
                          ]
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { created_at: { order: :asc } },
            { id: { order: :asc } }
          ],
          size: 10
        })
      end
    end

    describe '#last' do
      subject(:last_10_records_query) { paginator.last(10) }

      it 'generates the query' do
        expect(last_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          created_at: { lt: '2025-01-01' }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                created_at: '2025-01-01'
                              }
                            },
                            {
                              range: {
                                id: { lt: 1 }
                              }
                            }
                          ]
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { created_at: { order: :desc } },
            { id: { order: :desc } }
          ],
          size: 10
        })
      end
    end
  end

  describe '#after' do
    before do
      paginator.after('2025-01-01', 1)
    end

    describe '#first' do
      subject(:first_10_records_query) { paginator.first(10) }

      it 'generates the query with null field handling' do
        expect(first_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          created_at: { gt: '2025-01-01' }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                created_at: '2025-01-01'
                              }
                            },
                            {
                              range: {
                                id: { gt: 1 }
                              }
                            }
                          ]
                        }
                      },
                      {
                        bool: {
                          must_not: {
                            exists: {
                              field: :created_at
                            }
                          }
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { created_at: { order: :asc } },
            { id: { order: :asc } }
          ],
          size: 10
        })
      end
    end

    describe '#last' do
      subject(:last_10_records_query) { paginator.last(10) }

      it 'generates the query with null field handling' do
        expect(last_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          created_at: { gt: '2025-01-01' }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                created_at: '2025-01-01'
                              }
                            },
                            {
                              range: {
                                id: { gt: 1 }
                              }
                            }
                          ]
                        }
                      },
                      {
                        bool: {
                          must_not: {
                            exists: {
                              field: :created_at
                            }
                          }
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { created_at: { order: :desc } },
            { id: { order: :desc } }
          ],
          size: 10
        })
      end
    end
  end

  describe 'providing a different tie-breaker property' do
    let(:paginator) { described_class.new(query_hash, :vulnerability_id) }

    subject(:first_10_records_query) { paginator.after('2025-01-01', 1).first(10) }

    it 'generates the query based on given tie-breaker property' do
      expect(first_10_records_query).to eq({
        query: {
          bool: {
            should: [],
            must_not: [],
            must: [],
            filter: [
              {
                bool: {
                  should: [
                    {
                      range: {
                        created_at: { gt: '2025-01-01' }
                      }
                    },
                    {
                      bool: {
                        must: [
                          {
                            term: {
                              created_at: '2025-01-01'
                            }
                          },
                          {
                            range: {
                              vulnerability_id: { gt: 1 }
                            }
                          }
                        ]
                      }
                    },
                    {
                      bool: {
                        must_not: {
                          exists: {
                            field: :created_at
                          }
                        }
                      }
                    }
                  ]
                }
              }
            ]
          }
        },
        sort: [
          { created_at: { order: :asc } },
          { vulnerability_id: { order: :asc } }
        ],
        size: 10
      })
    end
  end

  context 'when sort contains more than one sort properties' do
    before do
      query_hash[:sort] = { severity: { order: :asc }, vulnerability_id: { order: :desc } }
    end

    let(:paginator) { described_class.new(query_hash) }

    subject(:first_10_records_query) { paginator.after(2, 100).first(10) }

    it 'generates the query based on second sort property as the tie-breaker property' do
      expect(first_10_records_query).to eq({
        query: {
          bool: {
            should: [],
            must_not: [],
            must: [],
            filter: [
              {
                bool: {
                  should: [
                    {
                      range: {
                        severity: { gt: 2 }
                      }
                    },
                    {
                      bool: {
                        must: [
                          {
                            term: {
                              severity: 2
                            }
                          },
                          {
                            range: {
                              vulnerability_id: { lt: 100 }
                            }
                          }
                        ]
                      }
                    },
                    {
                      bool: {
                        must_not: {
                          exists: {
                            field: :severity
                          }
                        }
                      }
                    }
                  ]
                }
              }
            ]
          }
        },
        sort: [
          { severity: { order: :asc } },
          { vulnerability_id: { order: :desc } }
        ],
        size: 10
      })
    end
  end

  context 'with null field value pagination', :use_clean_rails_redis_caching do
    let(:paginator) { described_class.new(query_hash) }

    before do
      query_hash[:sort] = { milestone_due_date: { order: :asc } }
    end

    describe '#after with nil cursor value (ASC)' do
      before do
        paginator.after(nil, 100)
      end

      subject(:first_10_records_query) { paginator.first(10) }

      it 'generates query with must_not exists filter for null values' do
        expect(first_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    must: [
                      {
                        bool: {
                          must_not: {
                            exists: {
                              field: :milestone_due_date
                            }
                          }
                        }
                      },
                      {
                        range: {
                          id: { gt: 100 }
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { milestone_due_date: { order: :asc } },
            { id: { order: :asc } }
          ],
          size: 10
        })
      end
    end

    describe '#after with non-null cursor value (ASC)' do
      before do
        paginator.after(1768003200000, 100)
      end

      subject(:first_10_records_query) { paginator.first(10) }

      it 'includes must_not exists clause to capture null values' do
        expect(first_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          milestone_due_date: { gt: 1768003200000 }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                milestone_due_date: 1768003200000
                              }
                            },
                            {
                              range: {
                                id: { gt: 100 }
                              }
                            }
                          ]
                        }
                      },
                      {
                        bool: {
                          must_not: {
                            exists: {
                              field: :milestone_due_date
                            }
                          }
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { milestone_due_date: { order: :asc } },
            { id: { order: :asc } }
          ],
          size: 10
        })
      end
    end

    describe '#after with non-null cursor value (DESC)' do
      before do
        query_hash[:sort] = { milestone_due_date: { order: :desc } }
        paginator.after(1768003200000, 100)
      end

      subject(:first_10_records_query) { paginator.first(10) }

      it 'includes must_not exists clause for DESC order too' do
        expect(first_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          milestone_due_date: { lt: 1768003200000 }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                milestone_due_date: 1768003200000
                              }
                            },
                            {
                              range: {
                                id: { lt: 100 }
                              }
                            }
                          ]
                        }
                      },
                      {
                        bool: {
                          must_not: {
                            exists: {
                              field: :milestone_due_date
                            }
                          }
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { milestone_due_date: { order: :desc } },
            { id: { order: :desc } }
          ],
          size: 10
        })
      end
    end

    describe '#before with non-null cursor value (ASC)' do
      before do
        paginator.before(1768003200000, 100)
      end

      subject(:first_10_records_query) { paginator.first(10) }

      it 'does not include must_not exists clause for backward pagination' do
        expect(first_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          milestone_due_date: { lt: 1768003200000 }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                milestone_due_date: 1768003200000
                              }
                            },
                            {
                              range: {
                                id: { lt: 100 }
                              }
                            }
                          ]
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { milestone_due_date: { order: :asc } },
            { id: { order: :asc } }
          ],
          size: 10
        })
      end
    end
  end
end
