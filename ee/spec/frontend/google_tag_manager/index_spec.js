import { merge } from 'lodash-es';
import {
  trackCombinedGroupProjectForm,
  trackFreeTrialAccountSubmissions,
  trackProjectImport,
  trackNewRegistrations,
  trackSaasTrialLeadSubmit,
  trackSaasTrialSubmit,
  trackTrialAcceptTerms,
  trackCompanyForm,
} from 'ee/google_tag_manager';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import { logError } from '~/lib/logger';

jest.mock('~/lib/logger');
jest.mock('uuid');

describe('ee/google_tag_manager/index', () => {
  let spy;

  beforeEach(() => {
    spy = jest.fn();

    window.dataLayer = {
      push: spy,
    };
  });

  const createHTML = ({ links = [], forms = [] } = {}) => {
    // .foo elements are used to test elements which shouldn't do anything
    const allLinks = links.concat({ cls: 'foo' });
    const allForms = forms.concat({ cls: 'foo' });

    const el = document.createElement('div');

    allLinks.forEach(({ cls = '', id = '', href = '#', text = 'Hello', attributes = {} }) => {
      const a = document.createElement('a');
      a.id = id;
      a.href = href || '#';
      a.className = cls;
      a.textContent = text;

      Object.entries(attributes).forEach(([key, value]) => {
        a.setAttribute(key, value);
      });

      el.append(a);
    });

    allForms.forEach(({ cls = '', id = '' }) => {
      const form = document.createElement('form');
      form.id = id;
      form.className = cls;

      el.append(form);
    });

    return el.innerHTML;
  };

  const triggerEvent = (selector, eventType) => {
    const el = document.querySelector(selector);

    el.dispatchEvent(new Event(eventType));
  };

  const getSelector = ({ id, cls }) => (id ? `#${id}` : `.${cls}`);

  const createTestCase = (subject, { forms = [], links = [] }) => {
    const expectedFormEvents = forms.map(({ expectation, ...form }) => ({
      selector: getSelector(form),
      trigger: 'submit',
      expectation,
    }));

    const expectedLinkEvents = links.map(({ expectation, ...link }) => ({
      selector: getSelector(link),
      trigger: 'click',
      expectation,
    }));

    return [
      subject,
      {
        forms,
        links,
        expectedEvents: [...expectedFormEvents, ...expectedLinkEvents],
      },
    ];
  };

  const createOmniAuthTestCase = (subject, accountType) =>
    createTestCase(subject, {
      forms: [
        {
          id: 'new_new_user',
          expectation: {
            event: 'accountSubmit',
            accountMethod: 'form',
            accountType,
          },
        },
      ],
      links: [
        {
          // id is needed so that the test selects the right element to trigger
          id: 'test-0',
          cls: 'js-track-omni-auth',
          attributes: {
            'data-provider': 'myspace',
          },
          expectation: {
            event: 'accountSubmit',
            accountMethod: 'myspace',
            accountType,
          },
        },
        {
          id: 'test-1',
          cls: 'js-track-omni-auth',
          attributes: {
            'data-provider': 'gitlab',
          },
          expectation: {
            event: 'accountSubmit',
            accountMethod: 'gitlab',
            accountType,
          },
        },
      ],
    });

  describe.each([
    createOmniAuthTestCase(trackFreeTrialAccountSubmissions, 'freeThirtyDayTrial'),
    createOmniAuthTestCase(trackNewRegistrations, 'standardSignUp'),
    createTestCase(trackProjectImport, {
      links: [
        {
          id: 'js-test-btn-0',
          cls: 'js-import-project-btn',
          attributes: { 'data-platform': 'bitbucket' },
          expectation: { event: 'projectImport', platform: 'bitbucket' },
        },
        {
          // id is needed so we trigger the right element in the test
          id: 'js-test-btn-1',
          cls: 'js-import-project-btn',
          attributes: { 'data-platform': 'github' },
          expectation: { event: 'projectImport', platform: 'github' },
        },
      ],
    }),

    createTestCase(trackCombinedGroupProjectForm, {
      forms: [
        {
          cls: 'js-groups-projects-form',
          expectation: { event: 'combinedGroupProjectFormSubmit' },
        },
      ],
    }),
  ])('%p', (subject, { links = [], forms = [], expectedEvents }) => {
    beforeEach(() => {
      setHTMLFixture(createHTML({ links, forms }));

      subject();
    });

    afterEach(() => {
      resetHTMLFixture();
    });

    it.each(expectedEvents)('when %p', ({ selector, trigger, expectation }) => {
      expect(spy).not.toHaveBeenCalled();

      triggerEvent(selector, trigger);

      expect(spy).toHaveBeenCalledTimes(1);
      expect(spy).toHaveBeenCalledWith(expectation);
      expect(logError).not.toHaveBeenCalled();
    });

    it('when random link is clicked, does nothing', () => {
      triggerEvent('a.foo', 'click');

      expect(spy).not.toHaveBeenCalled();
    });

    it('when random form is submitted, does nothing', () => {
      triggerEvent('form.foo', 'submit');

      expect(spy).not.toHaveBeenCalled();
    });
  });

  describe('with trackSaasTrialSubmit', () => {
    const cls = 'some-selector';
    const event = 'some-event';

    beforeEach(() => {
      setHTMLFixture(createHTML({ forms: [{ cls }] }));

      trackSaasTrialSubmit(`.${cls}`, event);
    });

    afterEach(() => {
      resetHTMLFixture();
    });

    it('triggers the event and submits successfully', () => {
      expect(spy).not.toHaveBeenCalled();

      triggerEvent(`.${cls}`, 'submit');

      expect(spy).toHaveBeenCalledTimes(1);
      expect(spy).toHaveBeenCalledWith({ event });
      expect(logError).not.toHaveBeenCalled();
    });

    it('when random link is clicked, does nothing', () => {
      triggerEvent('a.foo', 'click');

      expect(spy).not.toHaveBeenCalled();
    });

    it('when random form is submitted, does nothing', () => {
      triggerEvent('form.foo', 'submit');

      expect(spy).not.toHaveBeenCalled();
    });
  });

  describe('No listener events', () => {
    describe('when trackSaasTrialLeadSubmit is invoked', () => {
      it('should return some event', () => {
        expect(spy).not.toHaveBeenCalled();

        trackSaasTrialLeadSubmit('_eventLabel_');

        expect(spy).toHaveBeenCalledTimes(1);
        expect(spy).toHaveBeenCalledWith({ event: '_eventLabel_', valuableSignup: false });
        expect(logError).not.toHaveBeenCalled();
      });

      it('with an email domain', () => {
        expect(spy).not.toHaveBeenCalled();

        trackSaasTrialLeadSubmit('_eventLabel_', 'xyz.com');

        expect(spy).toHaveBeenCalledTimes(1);
        expect(spy).toHaveBeenCalledWith({ event: '_eventLabel_', valuableSignup: true });
        expect(logError).not.toHaveBeenCalled();
      });

      it('with a nonbusiness gitlab domain', () => {
        expect(spy).not.toHaveBeenCalled();

        trackSaasTrialLeadSubmit('_eventLabel_', 'gitlab.com');

        expect(spy).toHaveBeenCalledTimes(1);
        expect(spy).toHaveBeenCalledWith({ event: '_eventLabel_', valuableSignup: false });
        expect(logError).not.toHaveBeenCalled();
      });

      it('with an educational domain', () => {
        expect(spy).not.toHaveBeenCalled();

        trackSaasTrialLeadSubmit('_eventLabel_', 'test.edu');

        expect(spy).toHaveBeenCalledTimes(1);
        expect(spy).toHaveBeenCalledWith({ event: '_eventLabel_', valuableSignup: false });
        expect(logError).not.toHaveBeenCalled();
      });
    });

    it('when trackTrialAcceptTerms is invoked', () => {
      expect(spy).not.toHaveBeenCalled();

      trackTrialAcceptTerms();

      expect(spy).toHaveBeenCalledTimes(1);
      expect(spy).toHaveBeenCalledWith({ event: 'saasTrialAcceptTerms' });
      expect(logError).not.toHaveBeenCalled();
    });

    describe('when trackCompanyForm is invoked', () => {
      it('with an ultimate trial', () => {
        expect(spy).not.toHaveBeenCalled();

        trackCompanyForm('ultimate_trial');

        expect(spy).toHaveBeenCalledTimes(1);
        expect(spy).toHaveBeenCalledWith({
          event: 'aboutYourCompanyFormSubmit',
          aboutYourCompanyType: 'ultimate_trial',
          valuableSignup: false,
        });
        expect(logError).not.toHaveBeenCalled();
      });

      it('with a free account', () => {
        expect(spy).not.toHaveBeenCalled();

        trackCompanyForm('free_account');

        expect(spy).toHaveBeenCalledTimes(1);
        expect(spy).toHaveBeenCalledWith({
          event: 'aboutYourCompanyFormSubmit',
          aboutYourCompanyType: 'free_account',
          valuableSignup: false,
        });
        expect(logError).not.toHaveBeenCalled();
      });

      it('with a valid business email domain', () => {
        expect(spy).not.toHaveBeenCalled();

        trackCompanyForm('_eventLabel_', 'xyz.com');

        expect(spy).toHaveBeenCalledTimes(1);
        expect(spy).toHaveBeenCalledWith({
          event: 'aboutYourCompanyFormSubmit',
          aboutYourCompanyType: '_eventLabel_',
          valuableSignup: true,
        });
        expect(logError).not.toHaveBeenCalled();
      });

      it('with an uppercase email domain', () => {
        expect(spy).not.toHaveBeenCalled();

        trackCompanyForm('_eventLabel_', 'GMAIL.COM');

        expect(spy).toHaveBeenCalledTimes(1);
        expect(spy).toHaveBeenCalledWith({
          event: 'aboutYourCompanyFormSubmit',
          aboutYourCompanyType: '_eventLabel_',
          valuableSignup: false,
        });
        expect(logError).not.toHaveBeenCalled();
      });

      it('with a gitlab nonbusiness email domain', () => {
        expect(spy).not.toHaveBeenCalled();

        trackCompanyForm('_eventLabel_', 'gitlab.com');

        expect(spy).toHaveBeenCalledTimes(1);
        expect(spy).toHaveBeenCalledWith({
          event: 'aboutYourCompanyFormSubmit',
          aboutYourCompanyType: '_eventLabel_',
          valuableSignup: false,
        });
        expect(logError).not.toHaveBeenCalled();
      });

      it.each([
        ['test.edu', '\\.edu$ pattern'],
        ['mit.edu.cn', '\\.edu\\. pattern'],
        ['oxford.ac.uk', '\\.ac\\. pattern'],
        ['mail-student.university.org', '[.-]students?\\. pattern'],
        ['berlin.uni', '\\.uni(\\.|$) pattern'],
        ['etu.university.fr', '^etu\\. pattern'],
        ['etudiant.univ-paris.fr', 'etudiant pattern'],
        ['estudiant.uab.cat', 'estudiant pattern'],
        ['stud.polimi.it', '^stud\\. pattern'],
      ])('with educational domain %s (%s)', (domain) => {
        expect(spy).not.toHaveBeenCalled();

        trackCompanyForm('_eventLabel_', domain);

        expect(spy).toHaveBeenCalledTimes(1);
        expect(spy).toHaveBeenCalledWith({
          event: 'aboutYourCompanyFormSubmit',
          aboutYourCompanyType: '_eventLabel_',
          valuableSignup: false,
        });
        expect(logError).not.toHaveBeenCalled();
      });
    });
  });

  describe('when window has no dataLayer for trackSaasTrialSubmit', () => {
    beforeEach(() => {
      merge(window, { dataLayer: null });
    });

    it('no ops', () => {
      const cls = 'some-selector';
      setHTMLFixture(createHTML({ forms: [{ cls }] }));

      trackSaasTrialSubmit(`.${cls}`, 'some-event');

      triggerEvent(`.${cls}`, 'submit');

      expect(spy).not.toHaveBeenCalled();
      expect(logError).not.toHaveBeenCalled();

      resetHTMLFixture();
    });
  });

  describe('when window.dataLayer throws error', () => {
    const pushError = new Error('test');

    beforeEach(() => {
      window.dataLayer = {
        push() {
          throw pushError;
        },
      };
    });

    it('logs error', () => {
      const cls = 'some-selector';
      setHTMLFixture(createHTML({ forms: [{ cls }] }));

      trackSaasTrialSubmit(`.${cls}`, 'some-event');

      triggerEvent(`.${cls}`, 'submit');

      expect(logError).toHaveBeenCalledWith(
        'Unexpected error while pushing to dataLayer',
        pushError,
      );

      resetHTMLFixture();
    });
  });
});
