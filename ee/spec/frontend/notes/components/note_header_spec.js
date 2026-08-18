import Vue from 'vue';
import { PiniaVuePlugin } from 'pinia';
import { createTestingPinia } from '@pinia/testing';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import NoteHeader from '~/notes/components/note_header.vue';
import { globalAccessorPlugin } from '~/pinia/plugins';
import { useLegacyDiffs } from '~/diffs/stores/legacy_diffs';
import { useNotes } from '~/notes/store/legacy_notes';

Vue.use(PiniaVuePlugin);

describe('NoteHeader component', () => {
  let wrapper;
  let pinia;

  const createComponent = (props) => {
    wrapper = shallowMountExtended(NoteHeader, {
      pinia,
      propsData: { ...props },
    });
  };

  beforeEach(() => {
    pinia = createTestingPinia({ plugins: [globalAccessorPlugin] });
    useLegacyDiffs();
    useNotes();
  });

  it('shows internal note badge tooltip for group context when isInternalNote is true for epics', () => {
    createComponent({ isInternalNote: true, noteableType: 'epic' });

    expect(wrapper.findByTestId('internal-note-indicator').attributes('title')).toBe(
      'This internal note will always remain confidential',
    );
  });
});
