import { GlCollapsibleListbox, GlListboxItem } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import RunnerTagsDropdown from 'ee/vue_shared/components/runner_tags_dropdown/runner_tags_dropdown.vue';
import { getUniqueTagListFromEdges } from 'ee/vue_shared/components/runner_tags_dropdown/utils';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { createMockApolloProvider, PROJECT_ID, multipleTagListRequests } from './mocks/apollo_mock';
import { RUNNER_TAG_LIST_MOCK } from './mocks/mocks';

describe('RunnerTagsDropdown', () => {
  let wrapper;
  let handlers;

  const emptyTagListHandler = jest.fn().mockResolvedValue({
    data: {
      project: {
        id: PROJECT_ID,
        runners: {
          nodes: [],
        },
      },
    },
  });

  const createComponent = (propsData = {}, apolloOptions = { handlers: undefined }) => {
    const { requestHandlers, apolloProvider } = createMockApolloProvider(apolloOptions);
    handlers = requestHandlers;

    wrapper = mountExtended(RunnerTagsDropdown, {
      apolloProvider,
      propsData: {
        namespacePath: 'gitlab-org/testPath',
        ...propsData,
      },
      stubs: {
        GlListboxItem,
      },
    });
  };

  const createComponentAndWaitForPromises = async (propsData = {}, apolloOptions = {}) => {
    createComponent(propsData, apolloOptions);
    await waitForPromises();
  };

  const findTagsList = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDropdownItems = () => findTagsList().findAllComponents(GlListboxItem);
  const findSearchBox = () => wrapper.findByTestId('listbox-search-input');
  const toggleDropdown = async (event = 'shown') => {
    await findTagsList().vm.$emit(event);
  };

  describe('toggle text', () => {
    it('renders default text', async () => {
      await createComponentAndWaitForPromises();
      expect(findTagsList().props('toggleText')).toBe('Select runner tags');
    });

    it('renders selected tags', async () => {
      await createComponentAndWaitForPromises();
      await toggleDropdown();
      await findDropdownItems().at(0).vm.$emit('select', ['macos']);
      await findDropdownItems().at(2).vm.$emit('select', ['docker']);

      expect(findTagsList().props('toggleText')).toBe('macos, docker');
    });

    it('renders selected tags if search is empty, but tags are already selected', async () => {
      await createComponentAndWaitForPromises(
        { value: ['macos'] },
        { handlers: { projectRequestHandler: emptyTagListHandler } },
      );
      await findTagsList().vm.$emit('select', ['macos']);
      expect(findTagsList().props('toggleText')).toBe('macos');
    });

    it('renders custom placeholder for empty lists', async () => {
      const emptyTagsListPlaceholder = 'emptyTagsListPlaceholder';
      await createComponentAndWaitForPromises(
        { emptyTagsListPlaceholder },
        { handlers: { projectRequestHandler: emptyTagListHandler } },
      );

      expect(findTagsList().props('toggleText')).toBe(emptyTagsListPlaceholder);
    });

    it('renders default text for empty lists', async () => {
      await createComponentAndWaitForPromises(
        {},
        { handlers: { projectRequestHandler: emptyTagListHandler } },
      );
      expect(findTagsList().props('toggleText')).toBe('No tags exist');
    });
  });

  describe('disabled state', () => {
    it('disables listbox with props', async () => {
      await createComponentAndWaitForPromises({ disabled: true });
      expect(findTagsList().props('disabled')).toBe(true);
    });

    it('disables listbox for empty lists when not searching', async () => {
      await createComponentAndWaitForPromises(
        {},
        { handlers: { projectRequestHandler: emptyTagListHandler } },
      );
      expect(findTagsList().props('disabled')).toBe(true);
    });

    it('does not disable the listbox for empty lists when searching', async () => {
      await createComponentAndWaitForPromises(
        {},
        { handlers: { projectRequestHandler: emptyTagListHandler } },
      );
      await findTagsList().vm.$emit('search', 'macos');

      expect(findTagsList().props('disabled')).toBe(false);
    });
  });

  describe('error handling', () => {
    it('emits error event', async () => {
      await createComponentAndWaitForPromises(
        {},
        {
          handlers: { projectRequestHandler: jest.fn().mockRejectedValue({ error: new Error() }) },
        },
      );
      expect(wrapper.emitted('error')).toHaveLength(1);
    });

    it('emits error when invalid tag is provided or saved', async () => {
      await createComponentAndWaitForPromises({ value: ['invalid tag'] });
      expect(wrapper.emitted('error')).not.toHaveLength(0);
    });
  });

  describe('selected tags', () => {
    it('loads the data', async () => {
      await createComponentAndWaitForPromises();

      expect(handlers.projectRequestHandler).toHaveBeenCalledTimes(1);
      expect(handlers.projectRequestHandler).toHaveBeenCalledWith({
        fullPath: 'gitlab-org/testPath',
        tagList: '',
      });
      expect(findDropdownItems()).toHaveLength(5);
      expect(wrapper.emitted('tags-loaded')).toHaveLength(1);
      expect(wrapper.emitted('tags-loaded')[0][0]).toEqual([
        'macos',
        'linux',
        'docker',
        'backup',
        'development',
      ]);
    });

    it('selects existing tags', async () => {
      await createComponentAndWaitForPromises();
      await toggleDropdown();
      await findDropdownItems().at(0).vm.$emit('select', ['macos']);
      await findDropdownItems().at(2).vm.$emit('select', ['docker']);

      expect(wrapper.emitted('input')).toHaveLength(2);
    });

    it('filters out results by search', async () => {
      await createComponentAndWaitForPromises();
      await toggleDropdown();

      expect(findDropdownItems()).toHaveLength(
        getUniqueTagListFromEdges(RUNNER_TAG_LIST_MOCK).length,
      );

      await findSearchBox().setValue('macos');

      expect(handlers.projectRequestHandler).toHaveBeenCalledWith({
        fullPath: 'gitlab-org/testPath',
        tagList: 'macos',
      });
    });

    it('renders custom header', async () => {
      const testHeader = 'Test header';
      await createComponentAndWaitForPromises({ headerText: testHeader });
      expect(findTagsList().props('headerText')).toBe(testHeader);
    });

    it('renders existing selected tags', async () => {
      const value = ['linux', 'macos'];
      await createComponentAndWaitForPromises({ value });
      await toggleDropdown();

      expect(findDropdownItems().at(0).text()).toBe('linux');
      expect(findDropdownItems().at(1).text()).toBe('macos');
      expect(findDropdownItems().at(0).props('isSelected')).toBe(true);
      expect(findDropdownItems().at(1).props('isSelected')).toBe(true);
    });

    it('renders selected tags on top after re-open', async () => {
      await createComponentAndWaitForPromises();
      await toggleDropdown();

      expect(findDropdownItems().at(3).text()).toEqual('backup');
      expect(findDropdownItems().at(4).text()).toEqual('development');

      await findDropdownItems().at(3).vm.$emit('select', ['backup']);
      await findDropdownItems().at(4).vm.$emit('select', ['development']);

      /**
       * close - open dropdown
       */
      await toggleDropdown('hidden');
      await toggleDropdown();

      expect(findDropdownItems().at(0).text()).toEqual('development');
      expect(findDropdownItems().at(1).text()).toEqual('backup');
    });

    it('emits select event', async () => {
      await createComponentAndWaitForPromises();
      await toggleDropdown();
      await findDropdownItems().at(0).trigger('click');
      expect(wrapper.emitted('input')).toHaveLength(1);
    });

    it('fetches more data with selected tags', async () => {
      await createComponentAndWaitForPromises({ value: ['new-tag'] });

      expect(handlers.projectRequestHandler).toHaveBeenCalledTimes(2);
      expect(handlers.projectRequestHandler).toHaveBeenNthCalledWith(1, {
        fullPath: 'gitlab-org/testPath',
        tagList: '',
      });
      expect(handlers.projectRequestHandler).toHaveBeenNthCalledWith(2, {
        fullPath: 'gitlab-org/testPath',
        tagList: ['new-tag'],
      });
      expect(wrapper.emitted('error')).toHaveLength(1);
    });

    it('merges previous and new results from tagList query and does not emit an error', async () => {
      await createComponentAndWaitForPromises(
        { namespaceType: NAMESPACE_TYPES.PROJECT, value: ['xp'] },
        { handlers: { projectRequestHandler: multipleTagListRequests } },
      );
      await toggleDropdown();

      expect(findDropdownItems()).toHaveLength(2);
      expect(findDropdownItems().at(0).text()).toEqual('xp');
      expect(findDropdownItems().at(1).text()).toEqual('lion');
      expect(wrapper.emitted('error')).toBeUndefined();
    });

    it('does not fetch more data if the selected tag is retrieved in the first request', async () => {
      await createComponentAndWaitForPromises({ value: ['macos'] });
      expect(handlers.projectRequestHandler).toHaveBeenCalledTimes(1);
    });
  });

  describe('no runners', () => {
    beforeEach(async () => {
      const savedOnBackendTags = ['docker', 'node'];
      await createComponentAndWaitForPromises(
        { value: savedOnBackendTags },
        { handlers: { projectRequestHandler: emptyTagListHandler } },
      );
    });

    it('disables the listbox', () => {
      expect(findTagsList().props('disabled')).toBe(true);
    });
  });

  describe('loading runner tags', () => {
    it.each`
      namespaceTypeValue         | projectQueryCalled | groupQueryCalled
      ${NAMESPACE_TYPES.PROJECT} | ${1}               | ${0}
      ${NAMESPACE_TYPES.GROUP}   | ${0}               | ${1}
    `(
      'load correct query base on namespaceType',
      ({ namespaceTypeValue, projectQueryCalled, groupQueryCalled }) => {
        createComponent({ namespaceType: namespaceTypeValue });

        expect(handlers.projectRequestHandler).toHaveBeenCalledTimes(projectQueryCalled);
        expect(handlers.groupRequestHandler).toHaveBeenCalledTimes(groupQueryCalled);
      },
    );
  });

  describe('select all option', () => {
    it('selects all tags', async () => {
      await createComponentAndWaitForPromises();
      await findTagsList().vm.$emit('select-all');

      expect(wrapper.emitted('input')).toEqual([[getUniqueTagListFromEdges(RUNNER_TAG_LIST_MOCK)]]);
    });

    it('resets all selections', async () => {
      const uniqueTags = getUniqueTagListFromEdges(RUNNER_TAG_LIST_MOCK);
      await createComponentAndWaitForPromises({ value: uniqueTags });
      uniqueTags.forEach((_, index) => {
        expect(findDropdownItems().at(index).props('isSelected')).toBe(true);
      });

      await findTagsList().vm.$emit('reset');

      uniqueTags.forEach((_, index) => {
        expect(findDropdownItems().at(index).props('isSelected')).toBe(false);
      });

      expect(wrapper.emitted('input')).toEqual([[[]]]);
    });
  });
});
