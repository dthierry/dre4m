# Model

This section provides a shortcut description of the model behind `dre4m`. For
the purpose of laying out the core concepts, notation has been simplified from
the original paper.
The problem behind the diversification of the technology of a sector can be
summarized by the following linear program,

```math
\begin{equation}
    \begin{split}
        \min\; O\left(\mathbf{x}, \mathbf{p}\right):= 
        \alpha \, \mathtt{NPV} \left(\mathbf{x}, \mathbf{p}\right)
        + \beta \, \mathtt{termCost} \left(\mathbf{x}, \mathbf{p}\right)
        + \gamma \, \mathtt{softSl}\left(\mathbf{x}, \mathbf{p}\right)
        + , \; \text{s.t.} \; \mathbf{x} \in
        \mathcal{X}(\mathbf{p}).
    \end{split}
\end{equation}
```

In which, $\mathbf{x}$ represents the concatenated vector of variables of the
problem, and $\mathbf{p}$ represents the parameters of the system, e.g., capital
costs, demand, etc.

Moreover, the objective function has three main components, viz.

| Term                                                    | Description            |
|---------------------------------------------------------|------------------------|
| $\mathtt{NPV} \left(\mathbf{x}, \mathbf{p}\right)$      | Net present value      |
| $\mathtt{termCost} \left(\mathbf{x}, \mathbf{p}\right)$ | Terminal cost          |
| $\mathtt{softSl}\left(\mathbf{x}, \mathbf{p}\right)$    | Soft service-life cost |

