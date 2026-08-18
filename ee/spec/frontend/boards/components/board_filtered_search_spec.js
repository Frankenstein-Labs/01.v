import { nextTick } from 'vue';

import { mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import BoardFilteredSearch from 'ee/boards/components/board_filtered_search.vue';
import BoardFilteredSearchCe from '~/boards/components/board_filtered_search.vue';
import * as urlUtility from '~/lib/utils/url_utility';

describe('ee/BoardFilteredSearch', () => {
  let wrapper;
  let store;
  const updateTokensSpy = jest.fn();

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = mountExtended(BoardFilteredSearch, {
      store,
      propsData: {
        tokens: [],
        board: {},
        filters: {},
      },
      provide: {
        boardBaseUrl: 'root',
        initialFilterParams: [],
        ...provide,
      },
      stubs: {
        BoardFilteredSearchCe: stubComponent(BoardFilteredSearchCe, {
          methods: { updateTokens: updateTokensSpy },
        }),
      },
    });
  };

  const findFilteredSearch = () => wrapper.findComponent(BoardFilteredSearchCe);

  beforeEach(async () => {
    createComponent();

    jest.spyOn(urlUtility, 'updateHistory');

    wrapper.setProps({
      board: { labels: [{ title: 'test', color: 'black', id: '1' }] },
    });
    await nextTick();
  });

  it('updates url and tokens when board watcher is triggered', () => {
    expect(urlUtility.updateHistory).toHaveBeenCalledWith({
      url: '?label_name[]=test',
    });

    expect(findFilteredSearch().props()).toEqual(
      expect.objectContaining({ eeFilters: { labelName: ['test'] } }),
    );
    expect(updateTokensSpy).toHaveBeenCalled();
  });
});
