import { logError } from '~/lib/logger';

const PERSONAL_DOMAINS = new Set([
  '163.com',
  'aol.com',
  'att.net',
  'comcast.net',
  'facebook.com',
  'gitlab.com',
  'gmail.com',
  'gmx.com',
  'googlemail.com',
  'hotmail.com',
  'icloud.com',
  'live.com',
  'mail.ru',
  'outlook.com',
  'proton.me',
  'protonmail.com',
  'qq.com',
  'yahoo.com',
  'yandex.ru',
]);

const EDUCATION_DOMAIN_PATTERNS = [
  /\.edu$/,
  /\.edu\./,
  /\.ac\./,
  /[.-]students?\./,
  /\.uni(\.|$)/,
  /^etu\./,
  /etudiant/,
  /estudiant/,
  /^stud\./,
];

const isSupported = () => Boolean(window.dataLayer);
// window.dataLayer is set by adding partials to the appropriate view found in
// ee/app/views/layouts/_google_tag_manager_body.html.haml and _google_tag_manager_head.html.haml

const callIfSupported =
  (callback) =>
  (...args) => {
    if (isSupported()) {
      callback(...args);
    }
  };

const pushEvent = (event, args = {}) => {
  if (!window.dataLayer) {
    return;
  }

  try {
    window.dataLayer.push({
      event,
      ...args,
    });
  } catch (e) {
    logError('Unexpected error while pushing to dataLayer', e);
  }
};

const pushAccountSubmit = (accountType, accountMethod) =>
  pushEvent('accountSubmit', { accountType, accountMethod });

const trackFormSubmission = (accountType) => {
  const form = document.getElementById('new_new_user');
  form.addEventListener('submit', () => {
    pushAccountSubmit(accountType, 'form');
  });
};

const trackOmniAuthSubmission = (accountType) => {
  const links = document.querySelectorAll('.js-track-omni-auth');
  links.forEach((link) => {
    const { provider } = link.dataset;
    link.addEventListener('click', () => {
      pushAccountSubmit(accountType, provider);
    });
  });
};

const isValuableSignup = (emailDomain) => {
  if (!emailDomain) return false;
  const domain = emailDomain.toLowerCase();
  if (PERSONAL_DOMAINS.has(domain)) return false;
  if (EDUCATION_DOMAIN_PATTERNS.some((p) => p.test(domain))) return false;
  return true;
};

export const trackFreeTrialAccountSubmissions = () => {
  if (!isSupported()) {
    return;
  }

  trackFormSubmission('freeThirtyDayTrial');
  trackOmniAuthSubmission('freeThirtyDayTrial');
};

export const trackNewRegistrations = () => {
  if (!isSupported()) {
    return;
  }

  trackFormSubmission('standardSignUp');
  trackOmniAuthSubmission('standardSignUp');
};

export const trackSaasTrialLeadSubmit = callIfSupported((eventLabel, emailDomain) => {
  const valuableSignup = isValuableSignup(emailDomain);
  pushEvent(eventLabel, { valuableSignup });
});

export const trackSaasTrialSubmit = callIfSupported((selector, eventName) => {
  const form = document.querySelector(selector);

  if (!form) return;

  form.addEventListener('submit', () => {
    pushEvent(eventName);
  });
});

export const trackProjectImport = () => {
  if (!isSupported()) {
    return;
  }

  const importButtons = document.querySelectorAll('.js-import-project-btn');
  importButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const { platform } = button.dataset;
      pushEvent('projectImport', { platform });
    });
  });
};

export const trackTrialAcceptTerms = () => {
  if (!isSupported()) {
    return;
  }

  pushEvent('saasTrialAcceptTerms');
};

export const pushEECproductAddToCartEvent = () => {
  if (!isSupported()) {
    return;
  }

  window.dataLayer.push({
    event: 'EECproductAddToCart',
    ecommerce: {
      currencyCode: 'USD',
      add: {
        products: [
          {
            name: 'CI/CD Minutes',
            id: '0003',
            price: '10',
            brand: 'GitLab',
            category: 'DevOps',
            variant: 'add-on',
            quantity: 1,
          },
        ],
      },
    },
  });
};

export const trackCombinedGroupProjectForm = () => {
  if (!isSupported()) {
    return;
  }

  const form = document.querySelector('.js-groups-projects-form');
  form.addEventListener('submit', () => {
    pushEvent('combinedGroupProjectFormSubmit');
  });
};

export const trackCompanyForm = (aboutYourCompanyType, emailDomain) => {
  if (!isSupported()) {
    return;
  }

  const eventData = {
    aboutYourCompanyType,
    valuableSignup: isValuableSignup(emailDomain),
  };

  pushEvent('aboutYourCompanyFormSubmit', eventData);
};

export const saasTrialWelcome = () => {
  if (!isSupported()) {
    return;
  }

  const saasTrialWelcomeButton = document.querySelector('.js-trial-welcome-btn');

  saasTrialWelcomeButton?.addEventListener('click', () => {
    pushEvent('saasTrialWelcome');
  });
};
