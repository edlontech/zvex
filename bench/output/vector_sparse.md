Benchmark

Benchmark run from 2026-04-14 14:22:55.610846Z UTC

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



__Input: nnz_100__

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
    <td style="white-space: nowrap">from_sparse fp32</td>
    <td style="white-space: nowrap; text-align: right">442.08 K</td>
    <td style="white-space: nowrap; text-align: right">2.26 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;304.34%</td>
    <td style="white-space: nowrap; text-align: right">2.08 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">3.79 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_sparse fp16</td>
    <td style="white-space: nowrap; text-align: right">335.96 K</td>
    <td style="white-space: nowrap; text-align: right">2.98 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;215.89%</td>
    <td style="white-space: nowrap; text-align: right">2.79 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">5.29 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">from_sparse fp32</td>
    <td style="white-space: nowrap;text-align: right">442.08 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_sparse fp16</td>
    <td style="white-space: nowrap; text-align: right">335.96 K</td>
    <td style="white-space: nowrap; text-align: right">1.32x</td>
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
    <td style="white-space: nowrap">from_sparse fp32</td>
    <td style="white-space: nowrap">7.97 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">from_sparse fp16</td>
    <td style="white-space: nowrap">16.56 KB</td>
    <td>2.08x</td>
  </tr>
</table>



__Input: nnz_1000__

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
    <td style="white-space: nowrap">from_sparse fp32</td>
    <td style="white-space: nowrap; text-align: right">49.38 K</td>
    <td style="white-space: nowrap; text-align: right">20.25 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;8.55%</td>
    <td style="white-space: nowrap; text-align: right">20.04 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">23.96 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_sparse fp16</td>
    <td style="white-space: nowrap; text-align: right">35.88 K</td>
    <td style="white-space: nowrap; text-align: right">27.87 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;11.86%</td>
    <td style="white-space: nowrap; text-align: right">27.58 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">35.04 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">from_sparse fp32</td>
    <td style="white-space: nowrap;text-align: right">49.38 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_sparse fp16</td>
    <td style="white-space: nowrap; text-align: right">35.88 K</td>
    <td style="white-space: nowrap; text-align: right">1.38x</td>
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
    <td style="white-space: nowrap">from_sparse fp32</td>
    <td style="white-space: nowrap">78.28 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">from_sparse fp16</td>
    <td style="white-space: nowrap">164.22 KB</td>
    <td>2.1x</td>
  </tr>
</table>



__Input: nnz_500__

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
    <td style="white-space: nowrap">from_sparse fp32</td>
    <td style="white-space: nowrap; text-align: right">99.13 K</td>
    <td style="white-space: nowrap; text-align: right">10.09 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;35.08%</td>
    <td style="white-space: nowrap; text-align: right">9.92 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">12.92 &micro;s</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_sparse fp16</td>
    <td style="white-space: nowrap; text-align: right">71.27 K</td>
    <td style="white-space: nowrap; text-align: right">14.03 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;21.54%</td>
    <td style="white-space: nowrap; text-align: right">13.88 &micro;s</td>
    <td style="white-space: nowrap; text-align: right">22.42 &micro;s</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">from_sparse fp32</td>
    <td style="white-space: nowrap;text-align: right">99.13 K</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">from_sparse fp16</td>
    <td style="white-space: nowrap; text-align: right">71.27 K</td>
    <td style="white-space: nowrap; text-align: right">1.39x</td>
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
    <td style="white-space: nowrap">from_sparse fp32</td>
    <td style="white-space: nowrap">39.22 KB</td>
    <td>&nbsp;</td>
  </tr>
    <tr>
    <td style="white-space: nowrap">from_sparse fp16</td>
    <td style="white-space: nowrap">82.19 KB</td>
    <td>2.1x</td>
  </tr>
</table>