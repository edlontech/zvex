Benchmark

Benchmark run from 2026-04-14 14:21:42.451281Z UTC

## System

Benchmark suite executing on the following system:

<table style="width: 1%">
  <tr>
    <th style="width: 1%; white-space: nowrap">Operating System</th>
    <td>macOS</td>
  </tr><tr>
    <th style="white-space: nowrap">CPU Information</th>
    <td style="white-space: nowrap">Apple M4 Pro</td>
  </tr><tr>
    <th style="white-space: nowrap">Number of Available Cores</th>
    <td style="white-space: nowrap">12</td>
  </tr><tr>
    <th style="white-space: nowrap">Available Memory</th>
    <td style="white-space: nowrap">24 GB</td>
  </tr><tr>
    <th style="white-space: nowrap">Elixir Version</th>
    <td style="white-space: nowrap">1.19.5</td>
  </tr><tr>
    <th style="white-space: nowrap">Erlang Version</th>
    <td style="white-space: nowrap">28.4.1</td>
  </tr>
</table>

## Configuration

Benchmark suite executing with the following configuration:

<table style="width: 1%">
  <tr>
    <th style="width: 1%">:time</th>
    <td style="white-space: nowrap">5 s</td>
  </tr><tr>
    <th>:parallel</th>
    <td style="white-space: nowrap">1</td>
  </tr><tr>
    <th>:warmup</th>
    <td style="white-space: nowrap">2 s</td>
  </tr>
</table>

## Statistics



__Input: dim_128__

Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Devitation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp32</td>
    <td style="white-space: nowrap; text-align: right">773.92 K</td>
    <td style="white-space: nowrap; text-align: right">1.29 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;350.47%</td>
    <td style="white-space: nowrap; text-align: right">1.17 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">2.71 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp64</td>
    <td style="white-space: nowrap; text-align: right">770.21 K</td>
    <td style="white-space: nowrap; text-align: right">1.30 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;272.09%</td>
    <td style="white-space: nowrap; text-align: right">1.21 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">2.54 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp16</td>
    <td style="white-space: nowrap; text-align: right">435.21 K</td>
    <td style="white-space: nowrap; text-align: right">2.30 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;254.67%</td>
    <td style="white-space: nowrap; text-align: right">2.17 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">4.50 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list int8</td>
    <td style="white-space: nowrap; text-align: right">397.70 K</td>
    <td style="white-space: nowrap; text-align: right">2.51 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;34.75%</td>
    <td style="white-space: nowrap; text-align: right">2.38 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">4.33 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">from_list fp32</td>
    <td style="white-space: nowrap;text-align: right">773.92 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp64</td>
    <td style="white-space: nowrap; text-align: right">770.21 K</td>
    <td style="white-space: nowrap; text-align: right">1.0x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp16</td>
    <td style="white-space: nowrap; text-align: right">435.21 K</td>
    <td style="white-space: nowrap; text-align: right">1.78x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list int8</td>
    <td style="white-space: nowrap; text-align: right">397.70 K</td>
    <td style="white-space: nowrap; text-align: right">1.95x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">from_list fp32</td>
    <td style="white-space: nowrap">5.07 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">from_list fp64</td>
    <td style="white-space: nowrap">5.07 KB</td>
    <td>1.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">from_list fp16</td>
    <td style="white-space: nowrap">16.07 KB</td>
    <td>3.17x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">from_list int8</td>
    <td style="white-space: nowrap">7.07 KB</td>
    <td>1.39x</td>
  </tr>
</table>



__Input: dim_1536__

Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Devitation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp64</td>
    <td style="white-space: nowrap; text-align: right">74.24 K</td>
    <td style="white-space: nowrap; text-align: right">13.47 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;84.07%</td>
    <td style="white-space: nowrap; text-align: right">12.88 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">24.46 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp32</td>
    <td style="white-space: nowrap; text-align: right">73.96 K</td>
    <td style="white-space: nowrap; text-align: right">13.52 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;24.52%</td>
    <td style="white-space: nowrap; text-align: right">13.04 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">24.42 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp16</td>
    <td style="white-space: nowrap; text-align: right">39.56 K</td>
    <td style="white-space: nowrap; text-align: right">25.28 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;18.31%</td>
    <td style="white-space: nowrap; text-align: right">24.71 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">38.08 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list int8</td>
    <td style="white-space: nowrap; text-align: right">32.01 K</td>
    <td style="white-space: nowrap; text-align: right">31.24 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;11.42%</td>
    <td style="white-space: nowrap; text-align: right">30.21 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">44.29 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">from_list fp64</td>
    <td style="white-space: nowrap;text-align: right">74.24 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp32</td>
    <td style="white-space: nowrap; text-align: right">73.96 K</td>
    <td style="white-space: nowrap; text-align: right">1.0x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp16</td>
    <td style="white-space: nowrap; text-align: right">39.56 K</td>
    <td style="white-space: nowrap; text-align: right">1.88x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list int8</td>
    <td style="white-space: nowrap; text-align: right">32.01 K</td>
    <td style="white-space: nowrap; text-align: right">2.32x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">from_list fp64</td>
    <td style="white-space: nowrap">60.07 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">from_list fp32</td>
    <td style="white-space: nowrap">60.07 KB</td>
    <td>1.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">from_list fp16</td>
    <td style="white-space: nowrap">192.07 KB</td>
    <td>3.2x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">from_list int8</td>
    <td style="white-space: nowrap">84.07 KB</td>
    <td>1.4x</td>
  </tr>
</table>



__Input: dim_768__

Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Devitation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp32</td>
    <td style="white-space: nowrap; text-align: right">143.24 K</td>
    <td style="white-space: nowrap; text-align: right">6.98 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;80.83%</td>
    <td style="white-space: nowrap; text-align: right">6.54 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">16.63 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp64</td>
    <td style="white-space: nowrap; text-align: right">142.63 K</td>
    <td style="white-space: nowrap; text-align: right">7.01 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;85.93%</td>
    <td style="white-space: nowrap; text-align: right">6.54 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">16.25 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp16</td>
    <td style="white-space: nowrap; text-align: right">78.19 K</td>
    <td style="white-space: nowrap; text-align: right">12.79 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;14.65%</td>
    <td style="white-space: nowrap; text-align: right">12.67 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">17.58 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list int8</td>
    <td style="white-space: nowrap; text-align: right">65.62 K</td>
    <td style="white-space: nowrap; text-align: right">15.24 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;16.00%</td>
    <td style="white-space: nowrap; text-align: right">14.96 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">20.63 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">from_list fp32</td>
    <td style="white-space: nowrap;text-align: right">143.24 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp64</td>
    <td style="white-space: nowrap; text-align: right">142.63 K</td>
    <td style="white-space: nowrap; text-align: right">1.0x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list fp16</td>
    <td style="white-space: nowrap; text-align: right">78.19 K</td>
    <td style="white-space: nowrap; text-align: right">1.83x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_list int8</td>
    <td style="white-space: nowrap; text-align: right">65.62 K</td>
    <td style="white-space: nowrap; text-align: right">2.18x</td>
  </tr>

</table>



Memory Usage

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Factor</th>
  </tr>
  <tr>
    <td style="white-space: nowrap">from_list fp32</td>
    <td style="white-space: nowrap">30.07 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">from_list fp64</td>
    <td style="white-space: nowrap">30.07 KB</td>
    <td>1.0x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">from_list fp16</td>
    <td style="white-space: nowrap">96.07 KB</td>
    <td>3.19x</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">from_list int8</td>
    <td style="white-space: nowrap">42.07 KB</td>
    <td>1.4x</td>
  </tr>
</table>