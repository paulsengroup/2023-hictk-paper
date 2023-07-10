// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

#include <fmt/format.h>

#include <cassert>
#include <chrono>
#include <hictk/cooler.hpp>
#include <hictk/hic.hpp>
#include <hictk/hic/utils.hpp>
#include <memory>
#include <string_view>
#include <variant>

#include "benchmarks/fetch_and_sum/cli.hpp"

using namespace benchmarks;
using namespace hictk;

[[nodiscard]] inline std::pair<std::string, std::string> parse_bedpe(std::string_view line) {
  auto parse_bed = [&]() {
    assert(!line.empty());
    const auto pos1 = line.find('\t');
    const auto pos2 = line.find('\t', pos1 + 1);
    const auto pos3 = line.find('\t', pos2 + 1);

    auto tok = std::string{line.substr(0, pos3)};
    tok[pos1] = ':';
    tok[pos2] = '-';
    line.remove_prefix(pos3 + 1);
    return tok;
  };

  return std::make_pair(parse_bed(), parse_bed());
}

template <typename PixelIt>
[[nodiscard]] static double accumulate_interactions(PixelIt first_pixel, PixelIt last_pixel) {
  return std::accumulate(first_pixel, last_pixel, 0.0,
                         [&](const double accumulator, const auto &pixel) {
                           return accumulator + double(pixel.count);
                         });
}

void fetch_and_sum(const Config &c, cooler::File &&clr) {
  auto weights = clr.read_weights(c.weights);

  std::string line;
  while (std::getline(std::cin, line)) {
    const auto [range1, range2] = parse_bedpe(line);
    const auto t0 = std::chrono::system_clock::now();
    auto sel = clr.fetch(range1, range2, weights);
    const auto sum = accumulate_interactions(sel.begin<double>(), sel.end<double>());
    const auto t1 = std::chrono::system_clock::now();

    const auto delta = std::chrono::duration_cast<std::chrono::nanoseconds>(t1 - t0).count();

    fmt::print(FMT_STRING("{}\t{}\t{}\n"), line, sum, double(delta) / 1.0e9);
  }
}

void fetch_and_sum(const Config &c, hic::HiCFile &&hf) {
  hf.optimize_cache_size_for_random_access();
  const auto norm = hic::ParseNormStr(c.weights);

  std::string line;
  while (std::getline(std::cin, line)) {
    const auto [range1, range2] = parse_bedpe(line);
    const auto t0 = std::chrono::system_clock::now();
    auto sel = hf.fetch(range1, range2, norm);
    const auto sum = accumulate_interactions(sel.begin<double>(), sel.end<double>());
    const auto t1 = std::chrono::system_clock::now();

    const auto delta = std::chrono::duration_cast<std::chrono::nanoseconds>(t1 - t0).count();

    fmt::print(FMT_STRING("{}\t{}\t{}\n"), line, sum, double(delta) / 1.0e9);
  }
}

void fetch_and_sum(const benchmarks::Config &c) {
  if (hic::utils::is_hic_file(c.path)) {
    fetch_and_sum(c, hic::HiCFile(c.path, c.resolution));
  }
  fetch_and_sum(c, cooler::File::open_read_only_random_access(c.path));
}

int main(int argc, char **argv) noexcept {
  std::unique_ptr<Cli> cli{nullptr};
  std::ios::sync_with_stdio(false);
  try {
    cli = std::make_unique<Cli>(argc, argv);
    const auto config = cli->parse_arguments();
    if (!config.path.empty()) {
      fetch_and_sum(config);
    }

  } catch (const CLI::ParseError &e) {
    assert(cli);
    return cli->exit(e);  //  This takes care of formatting and printing error
                          //  messages (if any)
  } catch (const std::exception &e) {
    assert(cli);
    fmt::print(stderr, FMT_STRING("FAILURE! {} encountered the following error: {}."), argv[0],
               e.what());
    return 1;
  } catch (...) {
    fmt::print(stderr,
               FMT_STRING("FAILURE! {} encountered the following error: Caught an "
                          "unhandled exception!\n"),
               argv[0]);
    return 1;
  }
  return 0;
}
