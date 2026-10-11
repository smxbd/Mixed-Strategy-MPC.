# Approximate early-draft recovery report

Generated from saved `run.mat` artifacts; raw results were not edited.

| Cycle | Controller | Status | RMSE (km/h) | Distance (km) | Fuel (L) |
|---|---|---|---:|---:|---:|
| city200 | Existing | completed | 0.7761 | 1.011 | 3.927 |
| suburban400 | Existing | completed | 1.572 | 3.01 | 9.759 |
| stress300 | Existing | completed | 11.93 | 1.721 | 8.801 |
| city200 | LSTM | completed | 0.9875 | 1.015 | 4.003 |
| suburban400 | LSTM | completed | 2.772 | 2.967 | 9.447 |
| stress300 | LSTM | completed | 14.61 | 1.554 | 7.925 |
| city200 | Transformer | completed | 0.8706 | 1.01 | 3.546 |
| suburban400 | Transformer | completed | 1.705 | 3.005 | 8.83 |
| stress300 | Transformer | completed | 14.42 | 1.575 | 7.765 |

All nine cases are full-duration runs. Metrics are reported exactly from the saved artifacts; several scenarios differ from the historical target ranges, and those deviations are retained rather than adjusted. Tracking figures are stored in `recovery_figures/`.
