import { nextTick } from 'vue';
import { GlButton, GlButtonGroup, GlCollapsibleListbox, GlListboxItem, GlBadge } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import SplitButton from 'ee/vue_shared/security_reports/components/split_button.vue';
import * as urlUtility from '~/lib/utils/url_utility';

const defaultProps = {
  buttons: [
    {
      name: 'button one',
      tagline: "button one's tagline",
      isLoading: false,
      action: 'create-issue',
    },
    {
      name: 'button two',
      tagline: "button two's tagline",
      isLoading: false,
      action: 'create-jira-issue',
    },
  ],
};

describe('Split Button', () => {
  let wrapper;

  const findButtonGroup = () => wrapper.findComponent(GlButtonGroup);
  const findButton = () => wrapper.findComponent(GlButton);
  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findListboxItem = () => wrapper.findComponent(GlListboxItem);
  const findListboxBadge = () => findListbox().findComponent(GlBadge);
  const findButtonBadge = () => findButton().findComponent(GlBadge);

  const createComponent = (props, mountFn = shallowMountExtended) => {
    wrapper = mountFn(SplitButton, {
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  it('does not render button group if buttons array is empty', () => {
    createComponent({ buttons: [] });

    expect(findButtonGroup().exists()).toBe(false);
  });

  it('does not render the listbox if only 1 button is provided', () => {
    createComponent({ buttons: [defaultProps.buttons[0]] });

    expect(findListbox().exists()).toBe(false);
  });

  it('renders loading button and disable the listbox if loading prop is true', () => {
    createComponent({ loading: true });

    expect(findButton().attributes('loading')).toBe('true');
    expect(findListbox().attributes().disabled).toBe('true');
  });

  describe('selected button', () => {
    it('emits `create-issue` on button click', () => {
      createComponent({}, mountExtended);

      findButton().vm.$emit('click');

      expect(wrapper.emitted('create-issue')).toHaveLength(1);
    });

    it.each(['create-merge-request', 'download-patch'])(
      'emits `%s` on button click when it is the only action',
      (action) => {
        createComponent({ buttons: [{ ...defaultProps.buttons[0], action }] }, mountExtended);

        findButton().vm.$emit('click');

        expect(wrapper.emitted(action)).toHaveLength(1);
      },
    );

    it('emits `create-jira-issue` on button click once its action is selected', async () => {
      createComponent({}, mountExtended);

      findListbox().vm.$emit('select', 1);
      await nextTick();
      findButton().vm.$emit('click');

      expect(wrapper.emitted('create-jira-issue')).toHaveLength(1);
    });

    it('visits url if href property is specified', () => {
      const spy = jest.spyOn(urlUtility, 'visitUrl').mockReturnValue({});
      const href = 'https://gitlab.com';
      const { buttons } = defaultProps;

      createComponent({ buttons: [{ ...buttons[0], href }] });

      findButton().vm.$emit('click');

      expect(wrapper.emitted('create-issue')).toBeUndefined();
      expect(spy).toHaveBeenCalledWith(href, true);
    });

    it('renders the icon', () => {
      const icon = 'tanuki-ai';
      const { buttons } = defaultProps;
      createComponent({ buttons: [{ ...buttons[0], icon }] }, mountExtended);

      expect(findButton().props('icon')).toBe(icon);
    });

    it('renders the badge', () => {
      const badge = 'experiment';
      const { buttons } = defaultProps;
      createComponent({ buttons: [{ ...buttons[0], badge }] }, mountExtended);

      expect(findButtonBadge().text()).toBe(badge);
    });

    it('renders the tooltip', () => {
      const tooltipText = 'some tooltip message';
      const { buttons } = defaultProps;
      createComponent({ buttons: [{ ...buttons[0], tooltip: tooltipText }] }, mountExtended);

      const selectedButton = findButton();
      const tooltip = getBinding(selectedButton.element, 'gl-tooltip');

      expect(tooltip).toBeDefined();
      expect(selectedButton.attributes('title')).toBe(tooltipText);
      expect(selectedButton.attributes('aria-label')).toBe(tooltipText);
    });

    it('renders the button category', () => {
      const category = 'secondary';
      const { buttons } = defaultProps;
      createComponent({ buttons: [{ ...buttons[0], category }, buttons[1]] }, mountExtended);

      const selectedButton = findButton();

      expect(selectedButton.props('category')).toBe(category);
    });
  });

  describe('dropdown listbox', () => {
    it('renders a correct amount of listbox items', () => {
      createComponent();

      expect(findListbox().props('items')).toHaveLength(2);
    });

    it('renders both button text and tagline', () => {
      createComponent({}, mountExtended);

      const item = findListboxItem();
      expect(item.text()).toContain('button one');
      expect(item.text()).toContain("button one's tagline");
    });

    it('renders the badge', () => {
      const badge = 'experiment';
      const { buttons } = defaultProps;
      createComponent({ buttons: [{ ...buttons[0], badge }, buttons[1]] }, mountExtended);

      expect(findListboxBadge().text()).toBe(badge);
    });
  });
});
