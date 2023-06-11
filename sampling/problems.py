# Copyright (c) 2018 Gabriela Ochoa and Nadarajen Veerapen.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

from abc import ABC, abstractmethod
import random
import math


class ProblemInstance(ABC):
    @abstractmethod
    def maximize(self):
        pass

    def strictly_better(self, a, b):
        return a > b if self.maximize() else a < b

    def better_or_equal(self, a, b):
        return a >= b if self.maximize() else a <= b

    @abstractmethod
    def full_eval(self, sol):
        pass

    @abstractmethod
    def has_flip_delta_eval(self):
        pass

    @abstractmethod
    def flip_delta_eval(self, i):
        pass

    @abstractmethod
    def flip_with_delta(self, i):
        pass

    @abstractmethod
    def two_rnd_flips(self):
        pass


class OneMax(ProblemInstance):
    def __init__(self, n):
        self.n = n

    @staticmethod
    def full_eval(sol):
        sol.fitness = sum(sol.lst)
        sol.invalid = False

    @staticmethod
    def has_flip_delta_eval():
        return True

    @staticmethod
    def flip_delta_eval(sol, i):
        delta_fitness = 1 if sol.lst[i] == 0 else -1
        return (delta_fitness > 0), delta_fitness

    @staticmethod
    def flip_with_delta(sol, i, delta_fitness):
        sol.fitness += delta_fitness
        sol.lst[i] = 1 if sol.lst[i] == 0 else 0
        sol.invalid = False

    def two_rnd_flips(self, sol):
        i = random.randint(0, self.n - 1)
        j = i
        while j == i:
            j = random.randint(0, self.n - 1)
        delta_fitness = (1 if sol.lst[i] == 0 else -1) + (1 if sol.lst[j] == 0 else -1)
        sol.fitness += delta_fitness
        sol.lst[i] = 0 if sol.lst[i] == 1 else 1
        sol.lst[j] = 0 if sol.lst[j] == 1 else 1
        sol.invalid = False


class Knapsack(ProblemInstance):
    def __init__(self, filename):
        with open(filename, 'rU') as kfile:
            lines = kfile.readlines()
            self.n = int(lines[0])
            self.c = int(lines[self.n+1])
            self.items = [list(map(int, line.split())) for line in lines[1:self.n+1]]

    def __str__(self):
        return "Knapsack n=" + str(self.n) + " c=" + str(self.c) + " " + str(self.items)

    def maximize(self):
        return True

    def full_eval(self, sol):
        l = len(sol.lst)
        assert(l == self.n)
        weight = sum([sol.lst[i] * self.items[i][2] for i in range(l)])
        if weight > self.c:
            fitness = 0
        else:
            fitness = sum([sol.lst[i] * self.items[i][1] for i in range(l)])
        sol.fitness = fitness
        sol.weight = weight
        sol.invalid = False

    def weight(self, sol):
        return sum([sol.lst[i] * self.items[i][2] for i in range(len(sol.lst))])

    @staticmethod
    def has_flip_delta_eval():
        return False

    @staticmethod
    def flip_delta_eval(sol, i):
        raise NotImplementedError()

    @staticmethod
    def flip_with_delta(sol, i, delta_fitness):
        raise NotImplementedError()

    def two_rnd_flips(self, sol):
        """

        :param sol:
        """
        i = random.randint(0, self.n - 1)
        j = i
        while j == i:
            j = random.randint(0, self.n - 1)
        sol.lst[i] = 0 if sol.lst[i] == 1 else 1
        sol.lst[j] = 0 if sol.lst[j] == 1 else 1
        self.full_eval(sol)


class NumberPartitioning(ProblemInstance):
    def __init__(self, n, k, seed):
        """

        :param n: number of items
        :param k: threshold value
        :param seed: random seed to generate the items
        """
        rnd_gen = random.Random()
        rnd_gen.seed(seed)
        self.n = n
        self.k = k
        self.seed = seed
        l = int(round(math.pow(2, n*k)))
        self.a = [rnd_gen.randrange(1, l+1) for j in range(n)]

    def __str__(self):
        return "NPP n=" + str(self.n) + " k=" + str(self.k) + " seed=" + str(self.seed) + " " + str(self.a)

    def maximize(self):
        return False

    def full_eval(self, sol):
        l = len(sol.lst)
        assert (l == self.n)
        cost1 = sum([self.a[i] for i in range(l) if sol.lst[i] == 0])
        cost2 = sum([self.a[i] for i in range(l) if sol.lst[i] == 1])
        sol.fitness = cost1 - cost2 if cost1 > cost2 else cost2 - cost1
        sol.invalid = False

    @staticmethod
    def has_flip_delta_eval():
        return False

    @staticmethod
    def flip_delta_eval(self, i):
        raise NotImplementedError()

    @staticmethod
    def flip_with_delta(self, i):
        raise NotImplementedError()

    def two_rnd_flips(self, sol):
        """

        :param sol:
        """
        i = random.randint(0, self.n - 1)
        j = i
        while j == i:
            j = random.randint(0, self.n - 1)
        sol.lst[i] = 0 if sol.lst[i] == 1 else 1
        sol.lst[j] = 0 if sol.lst[j] == 1 else 1
        self.full_eval(sol)
