// Copyright (C) 2023 Roberto Rossini <roberros@uio.no>
//
// SPDX-License-Identifier: MIT

#pragma once

#include <fmt/format.h>

#include <CLI/CLI.hpp>
#include <cstdint>
#include <hictk/cooler/utils.hpp>
#include <hictk/hic/utils.hpp>
#include <string>

#include "benchmarks/fetch_and_sum/config.hpp"

namespace benchmarks {

class CoolerFileValidator : public CLI::Validator {
 public:
  CoolerFileValidator() : Validator("Cooler") {
    func_ = [](std::string &uri) -> std::string {
      try {
        if (!hictk::cooler::utils::is_cooler(uri)) {
          if (hictk::cooler::utils::is_multires_file(uri)) {
            return "URI points to a .mcool file: " + uri;
          }
          return "Not a valid Cooler: " + uri;
        }
        return "";
      } catch (...) {
        return "Not a valid Cooler: " + uri;
      }
    };
  }
};

class HiCFileValidator : public CLI::Validator {
 public:
  HiCFileValidator() : Validator("HiC") {
    func_ = [](std::string &path) -> std::string {
      if (hictk::hic::utils::is_hic_file(path)) {
        return "";
      }
      return "Not a valid .hic file: " + path;
    };
  }
};

inline const auto IsValidCoolerFile = CoolerFileValidator();
inline const auto IsValidHiCFile = HiCFileValidator();

class Cli {
  int _argc;
  char **_argv;
  std::string _exec_name;
  int _exit_code{1};
  Config _config{};
  CLI::App _cli{};

 public:
  Cli(int argc, char **argv) : _argc(argc), _argv(argv), _exec_name(*argv) { this->make_cli(); }
  [[nodiscard]] auto parse_arguments() -> Config {
    try {
      this->_cli.name(this->_exec_name);
      this->_cli.parse(this->_argc, this->_argv);
    } catch (const CLI::ParseError &e) {
      //  This takes care of formatting and printing error messages (if any)
      this->_exit_code = this->_cli.exit(e);
      return this->_config;
    } catch (const std::exception &e) {
      this->_exit_code = 1;
      throw std::runtime_error(fmt::format(FMT_STRING("An unexpected error has occurred while "
                                                      "parsing CLI arguments: {}. If you see this "
                                                      "message, please file an issue on GitHub"),
                                           e.what()));

    } catch (...) {
      this->_exit_code = 1;
      throw std::runtime_error(
          "An unknown error occurred while parsing CLI "
          "arguments! If you see this message, please "
          "file an issue on GitHub");
    }

    this->_exit_code = 0;
    return this->_config;
  }
  [[nodiscard]] int exit(const CLI::ParseError &e) const { return this->_cli.exit(e); }

  void make_cli() {
    auto &c = this->_config;
    auto &cli = this->_cli;

    cli.add_option("cooler", c.path, "Path to a .cool or .hic file (Cooler URI syntax supported).")
        ->check(IsValidCoolerFile | IsValidHiCFile)
        ->required();

    cli.add_option("--weights", c.weights,
                   "Name of the balancing weights to apply to interactions.");

    cli.add_option("--resolution", c.resolution,
                   "Matrix resolution. Ignored when input file is in Cooler format.");
  }
};

}  // namespace benchmarks
