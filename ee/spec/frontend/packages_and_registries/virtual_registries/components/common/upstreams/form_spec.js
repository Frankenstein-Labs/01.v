import { GlForm, GlFormGroup } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UpstreamForm from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/form.vue';
import TestUpstreamButton from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/test_button.vue';
import ContainerRoutes from 'ee/packages_and_registries/virtual_registries/pages/container/routes';

describe('UpstreamForm', () => {
  let wrapper;

  const upstream = {
    id: 1,
    name: 'foo',
    url: 'https://example.com',
    description: 'bar',
    username: 'bax',
    cacheValidityHours: 48,
    metadataCacheValidityHours: 48,
  };

  const defaultProvide = {
    mavenCentralUrl: 'https://repo1.maven.org/maven2',
    isMavenUpstream: true,
  };

  const createComponent = ({ props = {}, provide = {}, stubs = {} } = {}) => {
    wrapper = shallowMountExtended(UpstreamForm, {
      propsData: props,
      provide: {
        ...defaultProvide,
        ...provide,
      },
      stubs: {
        ...stubs,
      },
    });
  };

  const findForm = () => wrapper.findComponent(GlForm);
  const findNameInput = () => wrapper.findComponentByTestId('name-input');
  const findUpstreamUrlInput = () => wrapper.findComponentByTestId('upstream-url-input');
  const findUpstreamUrlDescription = () => wrapper.findByTestId('upstream-url-description');
  const findDescriptionInput = () => wrapper.findComponentByTestId('description-input');
  const findUsernameInput = () => wrapper.findComponentByTestId('username-input');
  const findPasswordInput = () => wrapper.findComponentByTestId('password-input');
  const findCacheValidityHoursInput = () =>
    wrapper.findComponentByTestId('cache-validity-hours-input');
  const findMetadataCacheValidityHoursInput = () =>
    wrapper.findComponentByTestId('metadata-cache-validity-hours-input');
  const findSubmitButton = () => wrapper.findByTestId('submit-button');
  const findCancelButton = () => wrapper.findComponentByTestId('cancel-button');
  const findTestUpstreamButton = () => wrapper.findComponent(TestUpstreamButton);

  beforeEach(() => {
    createComponent();
  });

  describe('renders', () => {
    it('renders Form', () => {
      expect(findForm().exists()).toBe(true);
    });

    describe('inputs', () => {
      it('renders Name input', () => {
        expect(findNameInput().exists()).toBe(true);
      });

      it('renders Upstream URL input', () => {
        expect(findUpstreamUrlInput().exists()).toBe(true);
      });

      it('renders Description input', () => {
        expect(findDescriptionInput().exists()).toBe(true);
      });

      it('renders Username input', () => {
        expect(findUsernameInput().exists()).toBe(true);
      });

      it('renders Password input', () => {
        expect(findPasswordInput().exists()).toBe(true);
      });

      it('renders Artifact cache validity hours input', () => {
        expect(findCacheValidityHoursInput().props('value')).toBe(24);
      });

      it('renders Metadata cache validity hours input when isMavenUpstream is true', () => {
        expect(findMetadataCacheValidityHoursInput().props('value')).toBe(24);
      });

      it('does not render Metadata cache validity hours input when isMavenUpstream is false', () => {
        createComponent({
          provide: {
            isMavenUpstream: false,
          },
        });
        expect(findMetadataCacheValidityHoursInput().exists()).toBe(false);
      });

      describe('when URL field is set to maven central', () => {
        beforeEach(() => {
          findUpstreamUrlInput().vm.$emit('input', defaultProvide.mavenCentralUrl);
        });

        it('sets Artifact cache validity hours input to readonly & value to 0', () => {
          expect(findCacheValidityHoursInput().props('value')).toBe(0);
          expect(findCacheValidityHoursInput().props('readonly')).toBe(true);
        });
      });
    });

    describe('inputs when upstream prop is set', () => {
      beforeEach(() => {
        createComponent({
          props: { upstream },
        });
      });

      it('renders Name input', () => {
        expect(findNameInput().props('value')).toBe('foo');
      });

      it('renders Upstream URL input', () => {
        expect(findUpstreamUrlInput().props('value')).toBe('https://example.com');
      });

      it('renders Description input', () => {
        expect(findDescriptionInput().props('value')).toBe('bar');
      });

      it('renders Username input', () => {
        expect(findUsernameInput().props('value')).toBe('bax');
      });

      it('renders Password input', () => {
        expect(findPasswordInput().props('value')).toBe('');
        expect(findPasswordInput().props('placeholder')).toBe('*****');
      });

      it('renders Artifact cache validity hours input', () => {
        expect(findCacheValidityHoursInput().props('value')).toBe(48);
      });

      it('renders Metadata cache validity hours input', () => {
        expect(findMetadataCacheValidityHoursInput().props('value')).toBe(48);
      });
    });

    describe('buttons', () => {
      it('renders Create upstream button', () => {
        expect(findSubmitButton().text()).toBe('Create upstream');
      });

      it('renders Cancel button', () => {
        expect(findCancelButton().text()).toBe('Cancel');
        expect(findCancelButton().props('href')).toBe('');
        expect(findCancelButton().props('to')).toEqual({});
      });

      it('renders `Save changes` button when upstream exists', () => {
        createComponent({ props: { upstream } });
        expect(findSubmitButton().text()).toBe('Save changes');
      });

      it('when upstream exists and routes are injected, sets route to Cancel button', () => {
        createComponent({
          props: { upstream },
          provide: {
            routes: ContainerRoutes,
          },
        });
        expect(findCancelButton().props('to')).toEqual({
          name: ContainerRoutes.showUpstreamRouteName,
          params: { id: upstream.id },
        });
      });

      it('sets upstreamPath to Cancel button href attribute when present', () => {
        createComponent({
          provide: {
            upstreamPath: 'upstream_path',
          },
        });
        expect(findCancelButton().props('href')).toBe('upstream_path');
      });
    });

    describe('Upstream URL field description', () => {
      it('shows default description when creating new upstream', () => {
        createComponent({
          stubs: {
            GlFormGroup,
          },
        });
        expect(findUpstreamUrlDescription().text()).toContain(
          'You can add GitLab-hosted repositories as upstreams',
        );
        expect(findUpstreamUrlDescription().text()).not.toContain(
          'Changing the URL will clear the username',
        );
      });

      it('shows warning description when editing existing upstream', () => {
        createComponent({
          props: { upstream },
          stubs: {
            GlFormGroup,
          },
        });
        expect(findUpstreamUrlDescription().text()).toContain(
          'You can add GitLab-hosted repositories as upstreams',
        );
        expect(findUpstreamUrlDescription().text()).toContain(
          'Changing the URL will clear the username and password',
        );
      });
    });
  });

  describe('emits events', () => {
    it('emits submit event when form is submitted and form is valid', () => {
      createComponent({ props: { upstream } });

      findForm().vm.$emit('submit', { preventDefault: () => {} });

      const submittedEvent = wrapper.emitted('submit');
      const [eventParams] = submittedEvent[0];

      expect(Boolean(submittedEvent)).toBe(true);
      expect(eventParams).toEqual(
        expect.objectContaining({
          name: 'foo',
          url: 'https://example.com',
          description: 'bar',
          username: 'bax',
          cacheValidityHours: 48,
          metadataCacheValidityHours: 48,
        }),
      );
    });

    it('emits submit event without metadataCacheValidityHours when isMavenUpstream is false', () => {
      createComponent({
        props: { upstream },
        provide: {
          isMavenUpstream: false,
        },
      });

      findForm().vm.$emit('submit', { preventDefault: () => {} });

      const submittedEvent = wrapper.emitted('submit');
      const [eventParams] = submittedEvent[0];

      expect(Boolean(submittedEvent)).toBe(true);
      expect(eventParams).toEqual(
        expect.objectContaining({
          name: 'foo',
          url: 'https://example.com',
          description: 'bar',
          username: 'bax',
          cacheValidityHours: 48,
        }),
      );
      expect(eventParams.metadataCacheValidityHours).toBeUndefined();
    });

    it('emits submit event with cacheValidityHours set to 0 when URL is maven central', () => {
      createComponent({ props: { upstream } });

      findUpstreamUrlInput().vm.$emit('input', defaultProvide.mavenCentralUrl);

      findForm().vm.$emit('submit', { preventDefault: () => {} });

      const submittedEvent = wrapper.emitted('submit');
      const [eventParams] = submittedEvent[0];

      expect(Boolean(submittedEvent)).toBe(true);
      expect(eventParams).toEqual(
        expect.objectContaining({
          name: 'foo',
          url: defaultProvide.mavenCentralUrl,
          description: 'bar',
          username: '',
          cacheValidityHours: 0,
          metadataCacheValidityHours: 48,
        }),
      );
    });

    it('does not emit a submit event when the form is not valid', () => {
      createComponent({ props: { upstream: { ...upstream, url: 'ftp://hello' } } });

      findForm().vm.$emit('submit', { preventDefault: () => {} });

      const submittedEvent = wrapper.emitted('submit');

      expect(Boolean(submittedEvent)).toBe(false);
    });

    it('emits cancel event when Cancel button is clicked', () => {
      findCancelButton().vm.$emit('click');
      expect(Boolean(wrapper.emitted('cancel'))).toBe(true);
      expect(wrapper.emitted('cancel')[0]).toEqual([]);
    });
  });

  describe('test upstream button', () => {
    it('renders Test upstream button component', () => {
      expect(findTestUpstreamButton().props()).toStrictEqual({
        disabled: true,
        upstreamId: null,
        url: '',
        username: '',
        password: '',
      });
    });

    it('enables button if valid URL is provided', async () => {
      await findUpstreamUrlInput().vm.$emit('input', 'https://gitlab.com');

      expect(findTestUpstreamButton().props('disabled')).toBe(false);
      expect(findTestUpstreamButton().props('username')).toBe('');
    });

    it('disables button if username is provided but password is not', async () => {
      await findUpstreamUrlInput().vm.$emit('input', 'https://gitlab.com');

      expect(findTestUpstreamButton().props('disabled')).toBe(false);

      await findUsernameInput().vm.$emit('input', 'username');

      expect(findTestUpstreamButton().props('disabled')).toBe(true);
    });

    describe('when upstream prop is set', () => {
      beforeEach(() => {
        createComponent({
          props: { upstream },
        });
      });

      it('renders Test upstream button component', () => {
        expect(findTestUpstreamButton().props()).toStrictEqual({
          disabled: false,
          upstreamId: upstream.id,
          url: upstream.url,
          username: upstream.username,
          password: '',
        });
      });
    });

    it('disables test upstream button component when the form is not valid', () => {
      createComponent({
        props: { upstream: { ...upstream, url: 'ftp://hello' } },
      });

      expect(findTestUpstreamButton().props('disabled')).toBe(true);
    });
  });

  describe('URL change behavior when editing upstream', () => {
    beforeEach(() => {
      createComponent({
        props: { upstream },
      });
    });

    it('clears username and password when URL is changed', async () => {
      expect(findUsernameInput().props('value')).toBe('bax');
      expect(findPasswordInput().props('placeholder')).toBe('*****');

      await findUpstreamUrlInput().vm.$emit('input', 'https://different-url.com');

      expect(findUsernameInput().props('value')).toBe('');
      expect(findPasswordInput().props('value')).toBe('');
      expect(findPasswordInput().props('placeholder')).toBe('');
    });

    it('restores username and password placeholder when URL is changed back to original', async () => {
      await findUpstreamUrlInput().vm.$emit('input', 'https://different-url.com');

      expect(findUsernameInput().props('value')).toBe('');
      expect(findPasswordInput().props('placeholder')).toBe('');

      await findUpstreamUrlInput().vm.$emit('input', 'https://example.com');

      expect(findUsernameInput().props('value')).toBe('bax');
      expect(findPasswordInput().props('placeholder')).toBe('*****');
    });

    it('does not restore credentials when URL is changed to a different URL', async () => {
      await findUpstreamUrlInput().vm.$emit('input', 'https://different-url.com');

      expect(findUsernameInput().props('value')).toBe('');

      await findUpstreamUrlInput().vm.$emit('input', 'https://another-url.com');

      expect(findUsernameInput().props('value')).toBe('');
      expect(findPasswordInput().props('placeholder')).toBe('');
    });

    it('does not show password placeholder when upstream has no username', async () => {
      createComponent({
        props: { upstream: { ...upstream, username: '' } },
      });

      expect(findPasswordInput().props('placeholder')).toBe('');

      await findUpstreamUrlInput().vm.$emit('input', 'https://different-url.com');

      expect(findPasswordInput().props('placeholder')).toBe('');
    });
  });

  describe('URL change behavior when creating new upstream', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not clear username when URL is changed on new upstream', async () => {
      await findUsernameInput().vm.$emit('input', 'testuser');
      await findUpstreamUrlInput().vm.$emit('input', 'https://example.com');

      expect(findUsernameInput().props('value')).toBe('testuser');

      await findUpstreamUrlInput().vm.$emit('input', 'https://different-url.com');

      expect(findUsernameInput().props('value')).toBe('testuser');
    });
  });
});
