import { GlProgressBar } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TrialWidget from 'ee/contextual_sidebar/components/trial_widget.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { makeMockUserGroupCalloutDismisser } from 'helpers/mock_user_group_callout_dismisser';
import UserGroupCalloutDismisser from '~/vue_shared/components/user_group_callout_dismisser.vue';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';

jest.mock('~/sentry/sentry_browser_wrapper');

describe('TrialWidget component', () => {
  let wrapper;
  let userGroupCalloutDismissSpy;

  const findRootElement = () => wrapper.findByTestId('trial-widget-root-element');
  const findWidgetTitle = () => wrapper.findByTestId('widget-title');
  const findCTAButton = () => wrapper.findByTestId('widget-cta');

  const findProgressBar = () => wrapper.findComponent(GlProgressBar);
  const findDismissButton = () => wrapper.findComponentByTestId('dismiss-btn');
  const findUserGroupCalloutDismisser = () => wrapper.findComponent(UserGroupCalloutDismisser);
  const findUserCalloutDismisser = () => wrapper.findComponent(UserCalloutDismisser);

  const provide = {
    trialType: 'duo_enterprise',
    daysRemaining: 40,
    percentageComplete: 33,
    trialDiscoverPagePath: '/discover',
    groupId: '1',
    featureId: '2',
    purchaseNowUrl: '/purchase',
  };

  const createComponent = (providers = {}, calloutOptions = {}) => {
    userGroupCalloutDismissSpy = jest.fn();
    const mockCalloutOptions = {
      dismiss: userGroupCalloutDismissSpy,
      shouldShowCallout: true,
      ...calloutOptions,
    };

    wrapper = shallowMountExtended(TrialWidget, {
      provide: {
        ...provide,
        ...providers,
      },
      stubs: {
        UserGroupCalloutDismisser: makeMockUserGroupCalloutDismisser(mockCalloutOptions),
        UserCalloutDismisser: makeMockUserGroupCalloutDismisser(mockCalloutOptions),
      },
    });
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  describe('rendered content', () => {
    it('renders with the correct id', () => {
      createComponent();
      expect(findRootElement().attributes('id')).toBe('trial-sidebar-widget');
    });

    it('shows the expected days remaining text when trial is active', () => {
      createComponent({ daysRemaining: 30, percentageComplete: 50 });
      expect(wrapper.text()).toContain('30 days left in trial');
    });

    it('does not render the dismiss button during active trial', () => {
      createComponent({ percentageComplete: 50 });
      expect(findDismissButton().exists()).toBe(false);
    });

    it('does not render when callout is dismissed', () => {
      createComponent({}, { shouldShowCallout: false });

      expect(findRootElement().exists()).toBe(false);
    });

    describe('when trial is active', () => {
      beforeEach(() => {
        createComponent({ daysRemaining: 30, percentageComplete: 50 });
      });

      it('renders the progress bar', () => {
        expect(findProgressBar().exists()).toBe(true);
      });

      it('renders the CTA button', () => {
        expect(findCTAButton().exists()).toBe(true);
      });

      describe('when under the threshold days', () => {
        beforeEach(() => {
          createComponent({ daysRemaining: 20, percentageComplete: 67 });
        });

        it('renders the CTA button', () => {
          expect(findCTAButton().exists()).toBe(true);
        });
      });

      describe('when on the last day of the trial', () => {
        beforeEach(() => {
          createComponent({ daysRemaining: 1, percentageComplete: 98 });
        });

        it('renders the progress bar', () => {
          expect(findProgressBar().exists()).toBe(true);
        });

        it('renders the CTA button', () => {
          expect(findCTAButton().exists()).toBe(true);
        });
      });

      describe('when trial has expired', () => {
        beforeEach(() => {
          createComponent({ daysRemaining: 0, percentageComplete: 100 });
        });

        it('shows correct body', () => {
          expect(wrapper.text()).toContain('Your trial of GitLab Duo Enterprise has ended');
        });

        it('renders the progress bar', () => {
          expect(findProgressBar().exists()).toBe(true);
        });

        it('renders the CTA button', () => {
          expect(findCTAButton().exists()).toBe(true);
        });

        it('renders the dismiss button', () => {
          expect(findDismissButton().exists()).toBe(true);
        });

        describe('dismissal', () => {
          it('should track the dismiss event', () => {
            const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

            findDismissButton().vm.$emit('click');

            expect(trackEventSpy).toHaveBeenCalledWith(
              'click_dismiss_button_on_trial_widget',
              {
                label: 'gitlab_duo_enterprise',
              },
              undefined,
            );
          });

          it('calls the dismiss function when dismiss button is clicked', () => {
            findDismissButton().vm.$emit('click');

            expect(userGroupCalloutDismissSpy).toHaveBeenCalled();
          });
        });
      });
    });
  });

  describe('widget title', () => {
    it.each([
      ['duo_pro', 'GitLab Duo Pro Trial', 'Your trial of GitLab Duo Pro has ended'],
      [
        'duo_enterprise',
        'GitLab Duo Enterprise Trial',
        'Your trial of GitLab Duo Enterprise has ended',
      ],
      ['ultimate_with_dap', 'GitLab Ultimate Trial', 'Your trial of GitLab Ultimate has ended'],
    ])('renders correctly for %s', (trialType, activeTitle, expiredTitle) => {
      createComponent({ trialType, daysRemaining: 30, percentageComplete: 50 });
      expect(findWidgetTitle().text()).toBe(activeTitle);

      createComponent({ trialType, daysRemaining: 0, percentageComplete: 100 });
      expect(findWidgetTitle().text()).toBe(expiredTitle);
    });
  });

  describe('when trial is active', () => {
    beforeEach(() => {
      createComponent({ daysRemaining: 30, percentageComplete: 50 });
    });

    it('renders the progress bar', () => {
      expect(findProgressBar().exists()).toBe(true);
    });

    it('renders the CTA button', () => {
      expect(findCTAButton().exists()).toBe(true);
    });
  });

  describe('when trial has expired', () => {
    it.each([
      ['duo_pro', 'Your trial of GitLab Duo Pro has ended'],
      ['duo_enterprise', 'Your trial of GitLab Duo Enterprise has ended'],
      ['ultimate_with_dap', 'Your trial of GitLab Ultimate has ended'],
    ])('shows correct title and upgrade text for %s', (trialType, expiredTitle) => {
      createComponent({ trialType, daysRemaining: -1, percentageComplete: 110 });

      expect(findWidgetTitle().text()).toBe(expiredTitle);
    });

    it('renders the progress bar', () => {
      createComponent({ daysRemaining: 0, percentageComplete: 100 });
      expect(findProgressBar().exists()).toBe(true);
    });

    it('renders the dismiss button', () => {
      createComponent({ daysRemaining: 0, percentageComplete: 100 });
      expect(findDismissButton().exists()).toBe(true);
    });
  });

  describe('dismisser component logic', () => {
    describe('when groupId is provided', () => {
      beforeEach(() => {
        createComponent({ groupId: '123' });
      });

      it('uses UserGroupCalloutDismisser component', () => {
        expect(findUserGroupCalloutDismisser().exists()).toBe(true);
        expect(findUserCalloutDismisser().exists()).toBe(false);
      });

      it('passes correct attributes to UserGroupCalloutDismisser', () => {
        expect(findUserGroupCalloutDismisser().props()).toMatchObject({
          featureName: '2',
          skipQuery: true,
          groupId: '123',
        });
      });
    });

    describe('when groupId is not provided', () => {
      beforeEach(() => {
        createComponent({ groupId: '' });
      });

      it('uses UserCalloutDismisser component', () => {
        expect(findUserCalloutDismisser().exists()).toBe(true);
        expect(findUserGroupCalloutDismisser().exists()).toBe(false);
      });

      it('passes correct attributes to UserCalloutDismisser', () => {
        expect(findUserCalloutDismisser().props()).toMatchObject({
          featureName: '2',
          skipQuery: true,
        });
      });

      it('does not pass groupId to UserCalloutDismisser', () => {
        expect(findUserCalloutDismisser().props().groupId).toBeUndefined();
      });
    });

    describe('when featureId is not provided', () => {
      beforeEach(() => {
        createComponent({ featureId: '' });
      });

      it('passes empty featureName to dismisser', () => {
        expect(findUserGroupCalloutDismisser().props().featureName).toBe('');
      });
    });

    describe('when both groupId and featureId are not provided', () => {
      beforeEach(() => {
        createComponent({ groupId: '', featureId: '' });
      });

      it('uses UserCalloutDismisser and passes empty featureName', () => {
        expect(findUserCalloutDismisser().exists()).toBe(true);
        expect(findUserGroupCalloutDismisser().exists()).toBe(false);
        expect(findUserCalloutDismisser().props().featureName).toBe('');
      });
    });
  });
});
