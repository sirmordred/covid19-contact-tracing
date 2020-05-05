/*
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

package com.google.android.apps.exposurenotification.activities;

import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import androidx.fragment.app.Fragment;
import com.google.android.apps.exposurenotification.R;

/**
 * Page 2 of the Verify Diagnosis & Notify Others flow
 */
public class ShareExposureCompleteFragment extends Fragment {
  @Override
  public View onCreateView(LayoutInflater inflater, ViewGroup parent, Bundle savedInstanceState) {
    return inflater.inflate(R.layout.fragment_share_exposure_complete, parent, false);
  }

  @Override
  public void onViewCreated(View view, Bundle savedInstanceState) {
    Button nextButton = view.findViewById(R.id.share_done_button);
    nextButton.setOnClickListener(
        v -> {
          if (getActivity() != null) {
            getActivity().finish();
          }
        });
  }
}
