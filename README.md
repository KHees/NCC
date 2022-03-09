NCC: R package for comparing treatment arms against control in platform trials with non-concurrent controls
================

NCC
---

`NCC` allows users to simulate platform trials and to compare arms using non-concurrent control data.

This package contains the following functions:

-   `datasim_cont()` - simulates data with continuous outcomes
-   `datasim_bin()` - simulates data with binary outcomes
-   `get_ss_matrix()` - computes sample sizes per arm and period
-   `linear_trend()` - generates linear trend for each patient
-   `sw_trend()` - generates stepwise trend for each patient

### Design overview

We consider a platform trial evaluating the efficacy of *K* treatment arms compared to a shared control. We assume that treatment arms enter the platform trial sequentially. In particular, we consider a trial starting with one initial treatment arm, where a new arm is added after every *δ* patients have been enrolled in the control arm.

We divide the duration of the trial into *S* periods, where the periods are the time intervals bounded by any treatment arm either entering or leaving the platform.

The bellow figure illustrates the considered trial desing with *K* treatment arms and *S* periods.

<img src="./figures/trial_general_1.png" width="70%" style="display: block; margin: auto;" />

<img src="./figures/trial_general_1.png" alt="Image Title" style="width:50.0%" />

Installation
------------

``` r
# install.packages("devtools") 
devtools::install_github("pavlakrotka/NCC")
```

Documentation
-------------

``` r
browseVignettes("NCC")
```

References
----------

\[1\] Bofill Roig, Marta, et al. *"On model-based time trend adjustments in platform trials with non-concurrent controls."* arXiv preprint arXiv:2112.06574 (2021).

\[2\] Lee, Kim May, and James Wason. *"Including non-concurrent control patients in the analysis of platform trials: is it worth it?."* BMC medical research methodology 20.1 (2020): 1-12.

------------------------------------------------------------------------

**Funding**

[EU-PEARL](https://eu-pearl.eu/) (EU Patient-cEntric clinicAl tRial pLatforms) project has received funding from the Innovative Medicines Initiative (IMI) 2 Joint Undertaking (JU) under grant agreement No 853966. This Joint Undertaking receives support from the European Union’s Horizon 2020 research and innovation programme and EFPIA andChildren’s Tumor Foundation, Global Alliance for TB Drug Development non-profit organisation, Spring works Therapeutics Inc. This publication reflects the authors’ views. Neither IMI nor the European Union, EFPIA, or any Associated Partners are responsible for any use that may be made of the information contained herein.
