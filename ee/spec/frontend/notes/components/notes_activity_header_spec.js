import { shallowMount } from '@vue/test-utils';
import NotesActivityHeader from '~/notes/components/notes_activity_header.vue';
import { notesFilters } from 'jest/notes/mock_data';

import DuoChatQuickAction from 'ee_component/ai/shared/widgets/duo_chat_quick_action.vue';

describe('EE ~/notes/components/notes_activity_header.vue', () => {
  let wrapper;

  const findDuoChatQuickAction = () => wrapper.findComponent(DuoChatQuickAction);

  const createComponent = ({ provide } = {}) => {
    wrapper = shallowMount(NotesActivityHeader, {
      propsData: {
        notesFilters,
      },
      provide: {
        resourceGlobalId: 'resourceGlobalId',
        glAbilities: { summarizeComments: true },
        glLicensedFeatures: { summarizeComments: true },
        ...provide,
      },
      stubs: {
        DuoChatQuickAction,
      },
    });
  };

  describe('when summarize comments is enabled', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the DuoChatQuickAction component', () => {
      expect(findDuoChatQuickAction().exists()).toBe(true);
    });
  });

  describe('when summarize comments is disabled', () => {
    it('does not render DuoChatQuickAction when there is no ability', () => {
      createComponent({
        provide: { glAbilities: { summarizeComments: false } },
      });

      expect(findDuoChatQuickAction().exists()).toBe(false);
    });

    it('does not render DuoChatQuickAction when feature is not enabled', () => {
      createComponent({
        provide: { glLicensedFeatures: { summarizeComments: false } },
      });

      expect(findDuoChatQuickAction().exists()).toBe(false);
    });
  });
});
