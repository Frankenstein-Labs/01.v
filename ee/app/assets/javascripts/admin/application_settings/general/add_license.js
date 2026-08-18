import LicenseDropzone from 'ee/admin/application_settings/general/components/license_dropzone.vue';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';

export default function initAddLicenseApp() {
  const licenseFile = document.querySelector('#js-add-license-toggle .license-file');
  const licenseKey = document.querySelector('#js-add-license-toggle .license-key');
  const uploadLicenseButton = document.querySelector('#js-add-license-toggle [type="submit"]');
  const acceptEULACheckBox = document.addLicense.accept_eula;
  const radioButtonList = document.addLicense.license_type;

  const showLicenseType = () => {
    licenseFile.classList.toggle('hidden', radioButtonList.value === 'key');
    licenseKey.classList.toggle('hidden', radioButtonList.value === 'file');
  };

  const toggleUploadLicenseButton = () => {
    uploadLicenseButton.toggleAttribute('disabled', !acceptEULACheckBox.checked);
  };

  const initLicenseUploadDropzone = () => {
    const el = document.getElementById('js-license-new-app');

    return initVueApp({
      el,
      name: 'LicenseDropzoneRoot',
      component: LicenseDropzone,
    });
  };

  radioButtonList.forEach((element) => element.addEventListener('change', showLicenseType));
  acceptEULACheckBox.addEventListener('change', toggleUploadLicenseButton);

  showLicenseType();
  toggleUploadLicenseButton();
  initLicenseUploadDropzone();
}
