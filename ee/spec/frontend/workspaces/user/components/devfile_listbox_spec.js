import { GlCollapsibleListbox, GlSprintf, GlButton } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue, { nextTick } from 'vue';
import DevfileListbox from 'ee/workspaces/user/components/devfile_listbox.vue';
import getDotDevfileYamlQuery from 'ee/workspaces/user/graphql/queries/get_dot_devfile_yaml.query.graphql';
import getDotDevfileFolderQuery from 'ee/workspaces/user/graphql/queries/get_dot_devfile_folder.query.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { DEFAULT_DEVFILE_OPTION } from 'ee/workspaces/user/constants';
import {
  GET_DOT_DEVFILE_YAML_RESULT,
  GET_DOT_DEVFILE_YAML_RESULT_WITH_NO_RETURN_RESULT,
  GET_DOT_DEVFILE_FOLDER_RESULT,
  GET_DOT_DEVFILE_FOLDER_WITH_NO_RETURN_RESULT,
  GET_DOT_DEVFILE_FOLDER_RESULT_SECOND_CALL,
} from '../../mock_data';

Vue.use(VueApollo);

describe('workspaces/user/components/devfile_listbox', () => {
  let wrapper;
  let mockApollo;
  let getDotDevfileYamlQueryHandler;
  let getDotDevfileFolderQueryHandler;

  const buildMockApollo = (
    yamlResult = GET_DOT_DEVFILE_YAML_RESULT,
    folderResult = GET_DOT_DEVFILE_FOLDER_RESULT,
    secondFolderResult = null,
  ) => {
    getDotDevfileYamlQueryHandler = jest.fn();
    getDotDevfileYamlQueryHandler.mockResolvedValue(yamlResult);

    getDotDevfileFolderQueryHandler = jest.fn();
    getDotDevfileFolderQueryHandler.mockResolvedValueOnce(folderResult);
    if (secondFolderResult !== null) {
      getDotDevfileFolderQueryHandler.mockResolvedValueOnce(secondFolderResult);
    }

    mockApollo = createMockApollo([
      [getDotDevfileYamlQuery, getDotDevfileYamlQueryHandler],
      [getDotDevfileFolderQuery, getDotDevfileFolderQueryHandler],
    ]);
  };

  const buildWrapper = (props = {}) => {
    wrapper = shallowMountExtended(DevfileListbox, {
      apolloProvider: mockApollo,
      propsData: {
        value: '',
        projectPath: 'test/project',
        devfileRef: 'main',
        ...props,
      },
      data() {
        return { hasNextPage: true };
      },
      stubs: {
        GlSprintf,
        GlButton,
      },
    });
  };

  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findErrorMessage = () => wrapper.findComponent(GlSprintf);
  const findReloadButton = () => wrapper.findComponent(GlButton);

  describe('when APIs succeeded', () => {
    beforeEach(async () => {
      buildMockApollo();
      buildWrapper();

      await waitForPromises();
    });

    it('renders GlCollapsibleListbox', () => {
      expect(findCollapsibleListbox().exists()).toBe(true);
    });

    it('contains correct listbox options', () => {
      expect(findCollapsibleListbox().props('items')).toEqual([
        {
          options: [{ text: 'Use GitLab default devfile', value: 'default_devfile' }],
          text: 'Default',
        },
        {
          options: [
            { text: '.devfile.yaml', value: '.devfile.yaml' },
            { text: '.devfile.yml', value: '.devfile.yml' },
            { text: '.devfile/.devfile.1.yaml', value: '.devfile/.devfile.1.yaml' },
            { text: '.devfile/.devfile.2.yaml', value: '.devfile/.devfile.2.yaml' },
          ],
          text: 'From your code',
        },
      ]);
    });

    it('does not display error message', () => {
      expect(findErrorMessage().exists()).toBe(false);
      expect(findReloadButton().exists()).toBe(false);
    });

    it('triggers getDevfiles when projectPath changes', async () => {
      expect(getDotDevfileYamlQueryHandler).toHaveBeenCalledTimes(1);
      expect(getDotDevfileFolderQueryHandler).toHaveBeenCalledTimes(1);

      wrapper.setProps({ projectPath: 'new/project' });
      await waitForPromises();

      expect(getDotDevfileYamlQueryHandler).toHaveBeenCalledTimes(2);
      expect(getDotDevfileFolderQueryHandler).toHaveBeenCalledTimes(2);
    });

    it('triggers getDevfiles when devfileRef changes', async () => {
      expect(getDotDevfileYamlQueryHandler).toHaveBeenCalledTimes(1);
      expect(getDotDevfileFolderQueryHandler).toHaveBeenCalledTimes(1);

      wrapper.setProps({ devfileRef: 'master' });
      await waitForPromises();

      expect(getDotDevfileYamlQueryHandler).toHaveBeenCalledTimes(2);
      expect(getDotDevfileFolderQueryHandler).toHaveBeenCalledTimes(2);
    });

    it('calls onBottomReached and loads more devfiles', async () => {
      buildMockApollo(
        GET_DOT_DEVFILE_YAML_RESULT,
        GET_DOT_DEVFILE_FOLDER_RESULT,
        GET_DOT_DEVFILE_FOLDER_RESULT_SECOND_CALL,
      );
      buildWrapper();
      await waitForPromises();

      await findCollapsibleListbox().vm.$emit('bottom-reached');
      await nextTick();

      expect(getDotDevfileFolderQueryHandler).toHaveBeenCalledTimes(2);
    });

    it('selects first available user devfile by default', () => {
      expect(findCollapsibleListbox().props('selected')).toBe('.devfile.yaml');
    });

    it('falls back to default devfile when no user devfiles exist', async () => {
      buildMockApollo(
        GET_DOT_DEVFILE_YAML_RESULT_WITH_NO_RETURN_RESULT,
        GET_DOT_DEVFILE_FOLDER_WITH_NO_RETURN_RESULT,
      );
      buildWrapper();
      await waitForPromises();

      expect(findCollapsibleListbox().props('selected')).toBe(DEFAULT_DEVFILE_OPTION);
    });
  });

  describe('when API failed', () => {
    it('displays error message when first query fails', async () => {
      buildMockApollo(GET_DOT_DEVFILE_YAML_RESULT, Promise.reject());
      buildWrapper();
      await waitForPromises();

      expect(findErrorMessage().exists()).toBe(true);
      expect(findReloadButton().exists()).toBe(true);
    });

    it('displays error message when second query fails', async () => {
      buildMockApollo(Promise.reject());
      buildWrapper();
      await waitForPromises();

      expect(findErrorMessage().exists()).toBe(true);
      expect(findReloadButton().exists()).toBe(true);
    });

    it('reloads devfiles when retry button is clicked', async () => {
      buildMockApollo(Promise.reject());
      buildWrapper();
      await waitForPromises();

      expect(findErrorMessage().exists()).toBe(true);

      await findReloadButton().trigger('click');
      await waitForPromises();

      expect(getDotDevfileYamlQueryHandler).toHaveBeenCalled();
    });
  });
});
