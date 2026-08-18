import apolloProvider from 'ee/subscriptions/graphql/graphql';
import CompanyForm from 'ee/registrations/components/company_form.vue';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';

initSimpleApp('#js-registrations-company-form', CompanyForm, {
  withApolloProvider: apolloProvider,
});
