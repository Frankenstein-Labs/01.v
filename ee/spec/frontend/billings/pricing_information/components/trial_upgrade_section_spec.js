import { GlButton, GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import TrialUpgradeSection from 'ee/billings/pricing_information/components/trial_upgrade_section.vue';
import {
  DUO_CHAT_FEATURE_ID,
  getTrialActiveFeatureHighlights,
} from 'ee/vue_shared/subscription/components/constants';
import { focusDuoChatInput } from 'ee/ai/utils';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

jest.mock('ee/ai/utils');

const { bindInternalEventDocument } = useMockInternalEventsTracking();

const mockGroupId = 1;
const mockGroupBillingHref = '/path/to/group/billing';
const mockExploreLinks = {
  [DUO_CHAT_FEATURE_ID]: '/link/to/duo/chat/settings',
  epics: '/link/to/epics',
  mergeTrains: '/link/to/merge/trains',
  escalationPolicies: '/link/to/escalation/policies',
  repositoryPullMirroring: '/link/to/repository/pull/mirroring',
  mergeRequestApprovals: '/link/to/merge/request/approvals',
};

describe('TrialUpgradeSection', () => {
  let wrapper;
  let trackingSpy;

  const findFeatureHighlights = () => wrapper.findAllByTestId('feature-highlight');
  const findPopovers = () => wrapper.findAllComponents(GlPopover);
  const findComparePlansLink = () => wrapper.findComponentByTestId('compare-plans-link');

  const createWrapper = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(TrialUpgradeSection, {
      propsData: {
        groupId: mockGroupId,
        groupBillingHref: mockGroupBillingHref,
        canAccessDuoChat: true,
        exploreLinks: mockExploreLinks,
        ...propsData,
      },
      stubs: {
        GlPopover: stubComponent(GlPopover, {
          template: `
            <div>
              <slot />
            </div>
          `,
        }),
      },
    });
    trackingSpy = bindInternalEventDocument(wrapper.element).trackEventSpy;
    trackingSpy.mockClear();
  };

  it('displays the correct amount of feature highlights', () => {
    createWrapper();

    const featureHighlights = findFeatureHighlights();

    expect(featureHighlights).toHaveLength(6);
  });

  it.each`
    index | title                          | docsLink                                                 | exploreLink
    ${0}  | ${'GitLab Duo Agent Platform'} | ${'/user/duo_agent_platform/_index'}                     | ${'/help/user/duo_agent_platform/_index'}
    ${1}  | ${'Epics'}                     | ${'/user/group/epics/_index.md'}                         | ${mockExploreLinks.epics}
    ${2}  | ${'Repository pull mirroring'} | ${'/user/project/repository/mirror/pull'}                | ${mockExploreLinks.repositoryPullMirroring}
    ${3}  | ${'Merge trains'}              | ${'/ci/pipelines/merge_trains'}                          | ${mockExploreLinks.mergeTrains}
    ${4}  | ${'Escalation policies'}       | ${'/operations/incident_management/escalation_policies'} | ${mockExploreLinks.escalationPolicies}
    ${5}  | ${'Merge request approvals'}   | ${'/user/project/merge_requests/approvals/settings'}     | ${mockExploreLinks.mergeRequestApprovals}
  `('renders the "$title" feature highlight', ({ index, title, docsLink, exploreLink }) => {
    createWrapper();
    const featureHighlight = findFeatureHighlights().at(index);
    const popover = findPopovers().at(index);

    expect(featureHighlight.text()).toContain(title);
    expect(popover.html()).toContain(docsLink);
    expect(popover.html()).toContain(exploreLink);
  });

  it('calls `focusDuoChatInput` when exploring GitLab Duo', () => {
    createWrapper();
    const popover = findPopovers().at(0);
    const button = popover.findComponent(GlButton);
    button.vm.$emit('click');

    expect(focusDuoChatInput).toHaveBeenCalled();
  });

  it('does not `focusDuoChatInput` when user does not have access to GitLab Duo', () => {
    createWrapper({ propsData: { canAccessDuoChat: false } });
    const popover = findPopovers().at(0);
    const button = popover.findComponent(GlButton);
    button.vm.$emit('click');

    expect(focusDuoChatInput).not.toHaveBeenCalled();
  });

  it.each(
    getTrialActiveFeatureHighlights().features.map((feature, index) => ({ ...feature, index })),
  )('tracks events for the "$title" feature', (feature) => {
    createWrapper({ propsData: { canAccessDuoChat: false } });
    const popover = findPopovers().at(feature.index);
    const button = popover.findComponent(GlButton);

    popover.vm.$emit('shown');
    expect(trackingSpy).toHaveBeenCalledWith(
      'render_premium_feature_popover_on_billings',
      { property: feature.id },
      undefined,
    );

    button.vm.$emit('click');
    expect(trackingSpy).toHaveBeenCalledWith(
      'click_cta_premium_feature_popover_on_billings',
      { property: feature.id },
      undefined,
    );
  });

  it('renders with the the "Compare plans" link', () => {
    createWrapper();

    expect(findComparePlansLink().props('href')).toBe('/path/to/group/billing');
  });
});
