# Copyright (c) 2018 Gabriela Ochoa and Nadarajen Veerapen.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import random
import copy
import logging
import getopt
import zipfile
import sys
import os
from problems import Knapsack, NumberPartitioning


class Solution:
    """Represents a solution.

    Attributes:
        lst - solution representation
        fitness - the fitness value associated to the solution
        invalid - the invalid flag should be set true if the fitness
                  needs to be recomputed following some modification
                  of the solution
    """

    def __init__(self, lst=[], fitness=0, invalid=False):
        self.fitness = fitness
        self.invalid = invalid
        self.lst = lst

    def __str__(self):
        #return str(self.fitness) + (" (invalid) " if self.invalid else " ") + ','.join(str(i) for i in self.lst)
        return str(self.fitness) + (" (invalid) " if self.invalid else " ") + ''.join(str(i) for i in self.lst)

    def init_rnd_bitstring(self, n):
        """Initialize the lst attribute to a uniformly random bitstring of length n.

        :param n: length of the bitstring
        :return:
        """
        self.lst = [random.randint(0, 1) for i in range(n)]
        self.invalid = True

    def init_rnd_permutation(self, n):
        """Initialize the lst attribute to a random permutation of length n.

        :param n: length of the permutation
        :return:
        """
        self.lst = list(range(n))
        random.shuffle(self.lst)
        self.invalid = True


def flip_neighbour_explorer(sol, problem_instance, first_improvement=True):
    """Explores the flip neighborhood of a solution using a first or best improvement strategy.
    For first improvement, the neighborhood is explored in a randomized order.

    :param sol: the solution whose neighborhood needs to be explored
    :param problem_instance: the problem instance object associated to the solution
    :param first_improvement: True for first improvement; false for best improvement
    :return: a boolean indicating whether an improving solution was found and the actual solution found
    """
    indices = list(range(len(sol.lst)))
    best_delta_fitness = 0
    best_sol = copy.deepcopy(sol)
    best_i = indices[0]
    improved = False

    if first_improvement:
        random.shuffle(indices)

    for i in indices:
        if problem_instance.has_flip_delta_eval():
            improved, delta_fitness = problem_instance.flip_delta_eval(sol, i)
            if improved:
                if problem_instance.strictly_better(delta_fitness, best_delta_fitness):
                    best_delta_fitness = delta_fitness
                    best_i = i
                if first_improvement:
                    break
        else:
            new_sol = copy.deepcopy(sol)
            new_sol.lst[i] = 0 if (new_sol.lst[i] == 1) else 1
            problem_instance.full_eval(new_sol)
            if problem_instance.strictly_better(new_sol.fitness, sol.fitness):
                improved = True
                if problem_instance.strictly_better(new_sol.fitness, best_sol.fitness):
                    best_sol = new_sol
                    best_i = i
                if first_improvement:
                    break

    if improved:
        if problem_instance.has_flip_delta_eval():
            new_sol = copy.deepcopy(sol)
            problem_instance.flip_with_delta(new_sol, best_i, delta_fitness)
            return improved, new_sol
        else:
            return improved, best_sol
    else:
        return improved, sol


def hc(init_sol, problem_instance, neighbour_explorer, first_improvement=True):
    """Performs a hill climb using first or best improvement

    :param init_sol: the initial solution for the hill climber
    :param problem_instance: the problem instance associated to the solution
    :param neighbour_explorer: a neighbor explorer function
    :param first_improvement: True for first improvement, false for best improvement
    :return: a boolean indicating whether an improving solution was found and the actual solution found
    """
    improved, sol = neighbour_explorer(init_sol, problem_instance, first_improvement)
    while improved:
        improved, sol = neighbour_explorer(sol, problem_instance, first_improvement)
    return sol


def logger(filename):
    lon_logger = logging.getLogger("LON_logger")
    lon_logger.setLevel(logging.INFO)
    lon_log_fh = logging.FileHandler(filename)
    lon_log_fh.setLevel(logging.INFO)
    lon_log_sh = logging.StreamHandler()
    lon_log_sh.setLevel(logging.INFO)
    formatter = logging.Formatter('%(message)s')
    lon_log_fh.setFormatter(formatter)
    lon_logger.addHandler(lon_log_fh)
    lon_logger.addHandler(lon_log_sh)
    return lon_logger


def close_handlers(lon_logger):
    for h in list(lon_logger.handlers):
        lon_logger.removeHandler(h)
        h.flush()
        h.close()


def ils(sol, problem_instance, local_search, neighbour_explorer, logname, non_impr_iters=100, first_improvement=True):
    """Iterated local search

    :param sol: the initial solution
    :param problem_instance: the problem instance associated to the solution
    :param local_search: a local search function
    :param neighbour_explorer: a neighborhood explorer function
    :param logname: file name of the log file
    :param non_impr_iters: the number of consecutive non improving iterations after which the search is stopped
    :param first_improvement: True for first improvement, false for best improvement
    :return: the best local optimum found
    """

    lon_logger = logger(logname) # start logging 
    lo = local_search(sol, problem_instance, neighbour_explorer, first_improvement)
    best_lo = copy.deepcopy(lo)
    non_improvement_cnt = 0
    while non_improvement_cnt < non_impr_iters:
        s = copy.deepcopy(best_lo)
        problem_instance.two_rnd_flips(s)
        lo = local_search(s, problem_instance, neighbour_explorer, first_improvement)
        lon_logger.info("%s %s", str(best_lo), str(lo)) # log jump attempt 
        if problem_instance.better_or_equal(lo.fitness, best_lo.fitness):
            best_lo = copy.deepcopy(lo)
            if problem_instance.strictly_better(lo.fitness, best_lo.fitness):
                non_improvement_cnt = 0
            else:
                non_improvement_cnt += 1
        else:
            non_improvement_cnt += 1
    close_handlers(lon_logger) # close files used by logger
    return best_lo


def main(argv):

    #file = "knap20.txt"
    zipname = "runs.zip"
    nb_runs = 100
    non_impr_iters = 100
    seed = 42

    opts, args = getopt.getopt(argv, "hf:r:i:s:", ["help", "file=", "runs=", "non_impr_iters=", "seed="])

    for opts, args in opts:
        if opts in ("-h", "--help"):
            print("Usage: " + sys.argv[0] + " -i <file1> [option]")
            sys.exit()
        elif opts in ("-f", "--file"):
            file = opts
            zipname = file + ".runs.zip"
        elif opts in ("-n", "--runs"):
            nb_runs = int(opts)
        elif opts in ("-i", "--non_impr_iters"):
            non_impr_iters = int(opts)
        elif opts in ("-s", "--seed"):
            seed = int(opts)
        else:
            assert False, "unhandled option"

    random.seed(seed)

    zf = zipfile.ZipFile(zipname, 'w', zipfile.ZIP_DEFLATED, True)

    try:
        for run in range(1,nb_runs+1):
            #instance = Knapsack(file)
            instance = NumberPartitioning(20, 0.5, 1)
            print(instance)
            s = Solution()
            s.init_rnd_bitstring(instance.n)
            instance.full_eval(s)
            print(s)
            log_name = "run" + str(run) + ".dat"
            s = ils(s, instance, hc, flip_neighbour_explorer, log_name, non_impr_iters)
            zf.write(log_name)
            os.remove(log_name)
            #print(s)
            #print(instance.weight(s))
    finally:
        zf.close()

if __name__ == "__main__":
	main(sys.argv[1:])
