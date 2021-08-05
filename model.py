#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Poincaré embedding module.
"""
# --------------------------------------------------------------------------- #
#                  MODULE HISTORY                                             #
# --------------------------------------------------------------------------- #
# Version          1
# Date             2021-07-28
# Author           LH John, E Fridgeirsson
# Note             Original version
#
# --------------------------------------------------------------------------- #
#                  SYSTEM IMPORTS                                             #
# --------------------------------------------------------------------------- #

# --------------------------------------------------------------------------- #
#                  OTHER IMPORTS                                              #
# --------------------------------------------------------------------------- #
from torch import sum, sqrt, log
from torch.nn import Embedding, Module
from numpy import linalg, arccosh

# --------------------------------------------------------------------------- #
#                  OWN IMPORTS                                                #
# --------------------------------------------------------------------------- #

# --------------------------------------------------------------------------- #
#                  META DATA                                                  #
# --------------------------------------------------------------------------- #
__status__ = 'Development'

# --------------------------------------------------------------------------- #
#                  CONSTANTS                                                  #
# --------------------------------------------------------------------------- #

# --------------------------------------------------------------------------- #
#                  GLOBAL VARIABLES                                           #
# --------------------------------------------------------------------------- #

# --------------------------------------------------------------------------- #
#                  CLASS DEFINITION                                           #
# --------------------------------------------------------------------------- #
class Model(Module):
    """Pytorch model of a Poincaré embedding.
    """

    def __init__(self, dim, size, init_weights=1e-3, epsilon=1e-7):
        """Initializes Poincaré embedding.
        :param dim: Output dimension of the embedding
        :param size: Input dimension of the embedding
        :param init_weights: Initial embedding weights
        :param epsilon: Small value to improve stability during convergence
        """
        super().__init__()
        self.embedding = Embedding(size, dim, sparse=False)
        self.embedding.weight.data.uniform_(-init_weights, init_weights)
        self.epsilon = epsilon

    def dist(self, u, v):
        """Calculates the Poincaré distance between two points.
        :param u: Point defined by a vector
        :param v: Another point defined by a vector
        :return: Poincaré distance between points u and v
        """
        sq_dist = sum((u - v) ** 2, dim=-1)
        squ_norm = sum(u ** 2, dim=-1)
        sqv_norm = sum(v ** 2, dim=-1)
        x = 1 + 2 * sq_dist / ((1 - squ_norm) * (1 - sqv_norm)) + self.epsilon
        z = sqrt(x ** 2 - 1)
        return log(x + z)

    def forward(self, inputs):
        e = self.embedding(inputs)
        o = e.narrow(dim=1, start=1, length=e.size(1) - 1)
        s = e.narrow(dim=1, start=0, length=1).expand_as(o)
        return self.dist(s, o)

    def dist_2(self, u, v):
        """An alternative implementation to calculate the Poincaré distance.
        This method uses numpy instead of torch. It is currently unused, but
        can be swapped into the forward() method of this class.
        :param u: Point defined by a vector
        :param v: Another point defined by a vector
        :return: Poincaré distance between points u and v
        """
        d = 1 + 2 * linalg.norm(u - v, axis=None) ** 2 / (
                    (1 - linalg.norm(u, axis=None) ** 2) * (
                        1 - linalg.norm(v, axis=None) ** 2) + self.epsilon)
        return arccosh(d)

# --------------------------------------------------------------------------- #
#                  END OF FILE                                                #
# --------------------------------------------------------------------------- #
