import Api from 'ee/api';
import { ERROR_FETCHING_COUNTRIES, ERROR_FETCHING_STATES } from 'ee/subscriptions/constants';
import { createAlert } from '~/alert';

const COUNTRY_TYPE = 'Country';
const STATE_TYPE = 'State';

export const gitLabResolvers = {
  Query: {
    countries: () => {
      return Api.fetchCountries()
        .then(({ data }) =>
          data.map(([name, alpha2, flag, internationalDialCode]) => ({
            name,
            id: alpha2,
            flag,
            internationalDialCode,
            __typename: COUNTRY_TYPE,
          })),
        )
        .catch(() => createAlert({ message: ERROR_FETCHING_COUNTRIES }));
    },
    states: (_, { countryId }) => {
      return Api.fetchStates(countryId)
        .then(({ data }) => {
          return Object.entries(data).map(([key, value]) => ({
            id: value,
            name: key,
            __typename: STATE_TYPE,
          }));
        })
        .catch(() => createAlert({ message: ERROR_FETCHING_STATES }));
    },
  },
};
