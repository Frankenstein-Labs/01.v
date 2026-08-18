import { shallowMount } from '@vue/test-utils';
import { v4 as uuidv4 } from 'uuid';
import Vue from 'vue';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
import waitForPromises from 'helpers/wait_for_promises';
import NotesApp from '~/notes/components/notes_app.vue';
import AiSummary from 'ee_component/notes/components/ai_summary.vue';
// TODO: use generated fixture (https://gitlab.com/gitlab-org/gitlab-foss/issues/62491)
import { globalAccessorPlugin } from '~/pinia/plugins';
import { useLegacyDiffs } from '~/diffs/stores/legacy_diffs';
import { useNotes } from '~/notes/store/legacy_notes';
import { useBatchComments } from '~/batch_comments/store';
import * as mockData from '../../../../../spec/frontend/notes/mock_data';

jest.mock('~/behaviors/markdown/render_gfm');
jest.mock('uuid');

const propsData = {
  noteableData: mockData.noteableDataMock,
  notesData: mockData.notesDataMock,
  notesFilters: mockData.notesFilters,
};

Vue.use(PiniaVuePlugin);

describe('note_app', () => {
  let mountComponent;
  let wrapper;
  let pinia;

  beforeEach(() => {
    pinia = createTestingPinia({
      plugins: [globalAccessorPlugin],
      stubActions: false,
    });
    useLegacyDiffs();
    useNotes();
    useBatchComments();
    mountComponent = () => {
      return shallowMount(NotesApp, {
        pinia,
        propsData,
        provide: {
          resourceGlobalId: 'gid://Gitlab/Issue/1',
        },
        data() {
          return {
            aiLoading: false,
          };
        },
        stubs: {
          AiSummary,
        },
      });
    };
  });

  describe('provide', () => {
    beforeEach(async () => {
      uuidv4.mockImplementation(() => 'uuid');

      wrapper = await mountComponent();
      await waitForPromises();
    });

    it('provides summarizeClientSubscriptionId', () => {
      expect(wrapper.findComponent(AiSummary).vm.summarizeClientSubscriptionId).toBe('uuid');
    });
  });
});
