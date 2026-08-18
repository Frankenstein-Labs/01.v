import { GlEmptyState, GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import EmptyState, { i18n } from 'ee/workspaces/common/components/workspaces_list/empty_state.vue';

const SVG_PATH = '/assets/illustrations/empty_states/empty_workspaces.svg';

describe('workspaces/common/components/workspaces_list/empty_state.vue', () => {
  let wrapper;

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);

  const createComponent = ({ propsData = {} }) => {
    // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
    wrapper = shallowMount(EmptyState, {
      provide: {
        emptyStateSvgPath: SVG_PATH,
      },
      propsData,
      stubs: {
        GlEmptyState,
      },
    });
  };

  describe('when no workspaces exist', () => {
    it('should render empty workspace state', () => {
      createComponent({ propsData: { newWorkspacePath: '' } });

      expect(findEmptyState().props()).toMatchObject({
        title: i18n.title,
        description: i18n.description,
        svgPath: SVG_PATH,
      });
    });

    describe('when new workspace path is provided', () => {
      it('displays a button that navigates to the new workspace page', () => {
        const newWorkspacePath = '/workspaces/new';

        createComponent({ propsData: { newWorkspacePath } });

        const button = findEmptyState().findComponent(GlButton);

        expect(button.props()).toMatchObject({
          variant: 'confirm',
        });
        expect(button.attributes()).toMatchObject({
          to: newWorkspacePath,
        });
      });
    });

    describe('when new workspace path is not provided', () => {
      it('does not display a button', () => {
        createComponent({ propsData: { newWorkspacePath: '' } });
        expect(findEmptyState().findComponent(GlButton).exists()).toBe(false);
      });
    });

    describe('when title and description are provided', () => {
      it('should pass title and description to empty state', () => {
        createComponent({
          propsData: { title: 'Inferno', description: 'In the midway of this our mortal life' },
        });

        expect(findEmptyState().props()).toMatchObject({
          title: 'Inferno',
          description: 'In the midway of this our mortal life',
        });
      });
    });
  });
});
