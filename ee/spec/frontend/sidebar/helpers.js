import { GlCollapsibleListbox } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';

const findListbox = (wrapper) => wrapper.findComponent(GlCollapsibleListbox);

export const search = async (wrapper, searchTerm) => {
  findListbox(wrapper).vm.$emit('search', searchTerm);

  await waitForPromises();
  jest.runAllTimers(); // Account for debouncing
};

// Used with createComponentWithApollo which uses 'mount'
export const clickEdit = async (wrapper) => {
  // Open the listbox so its lazy-fetch fires via the @shown handler.
  findListbox(wrapper).vm.$emit('shown');

  jest.runAllTimers();
  await waitForPromises();
};
