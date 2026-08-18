import { GlLink } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import OrbitExploreEmptyState from 'ee/orbit/components/orbit_explore_empty_state.vue';

describe('OrbitExploreEmptyState tracking', () => {
  let wrapper;

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const ownerGroup = {
    name: 'Owner Group',
    fullPath: 'owner-group',
    avatarUrl: null,
    knowledgeGraphAvailable: true,
    knowledgeGraphEnabled: false,
    maxAccessLevel: { integerValue: 50 },
  };

  const nonOwnerGroup = {
    name: 'Member Group',
    fullPath: 'member-group',
    avatarUrl: null,
    knowledgeGraphAvailable: true,
    knowledgeGraphEnabled: false,
    maxAccessLevel: { integerValue: 30 },
  };

  const createComponent = (availableGroups) =>
    mount(OrbitExploreEmptyState, {
      propsData: { availableGroups },
      stubs: {
        TurnOnIndexingModal: true,
        OrbitEmptyState: { template: '<div><slot /></div>' },
        GlAvatar: true,
        GlModal: true,
      },
    });

  it('tracks click_orbit_get_started_empty_state when the Get started button is clicked', async () => {
    wrapper = createComponent([ownerGroup]);
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    await wrapper.find('[data-testid="orbit-get-started-btn"]').trigger('click');

    expect(trackEventSpy).toHaveBeenCalledWith(
      'click_orbit_get_started_empty_state',
      {},
      undefined,
    );
  });

  it('tracks click_orbit_setup_guide_empty_state when the Setup guide button is clicked', async () => {
    wrapper = createComponent([nonOwnerGroup]);
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    await wrapper.find('[data-testid="orbit-setup-guide-btn"]').trigger('click');

    expect(trackEventSpy).toHaveBeenCalledWith(
      'click_orbit_setup_guide_empty_state',
      {},
      undefined,
    );
  });

  it('exposes data-event-tracking on the View Owners link', () => {
    wrapper = createComponent([nonOwnerGroup]);

    const ownersLink = wrapper
      .findAllComponents(GlLink)
      .wrappers.find((link) => link.text() === 'View Owners');

    expect(ownersLink.attributes('data-event-tracking')).toBe(
      'click_orbit_view_owners_empty_state',
    );
  });

  it('does not render the Get started button for non-owner groups', () => {
    wrapper = createComponent([nonOwnerGroup]);

    expect(wrapper.find('[data-testid="orbit-get-started-btn"]').exists()).toBe(false);
  });

  it('does not render the Setup guide button for owner groups', () => {
    wrapper = createComponent([ownerGroup]);

    expect(wrapper.find('[data-testid="orbit-setup-guide-btn"]').exists()).toBe(false);
  });

  it('shows the no-eligible-groups message when no groups are available', () => {
    wrapper = createComponent([]);

    const message = wrapper.find('[data-testid="orbit-no-available-groups"]');
    expect(message.exists()).toBe(true);
    expect(message.text()).toBe('No eligible groups are available for Orbit.');
  });

  it('does not show the no-eligible-groups message when groups are available', () => {
    wrapper = createComponent([ownerGroup]);

    expect(wrapper.find('[data-testid="orbit-no-available-groups"]').exists()).toBe(false);
  });
});
