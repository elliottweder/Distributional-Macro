### A Pluto.jl notebook ###
# v0.19.4

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 06657523-1871-4f45-a7a1-24e67df068b2
using PlutoUI; TableOfContents()

# ╔═╡ 30e81715-4076-4961-b95f-77e13279fbc8
using DataFrames

# ╔═╡ dbe5a87e-cee5-49c3-b8fe-dc8dbbd55650
using ForwardDiff

# ╔═╡ dfbf76d4-fd41-4481-978f-d6a690b03c70
using Optim

# ╔═╡ 87c8692c-d18f-4c3d-89bd-b7d270f12e64
begin
	using Plots, LaTeXStrings
	theme(:dao)
	default(size = 500 .* (√2, 1), dpi = 150)
end

# ╔═╡ b5f3a5a5-206d-49ae-9b15-612f22cf3bfe
md"""
`redistributive-growth.jl` | **Version 1.0** | _last updated on May 25, 2022_
"""

# ╔═╡ 578fba17-11eb-4057-8f18-fb7835e701d6
md"""
# Redistributive Growth

This lecture is based on the paper **Redistributive Growth** (Döttling and Perotti; 2019). This paper tries to explain various macroeconomic trends with a technological shift to intangible capital.
"""

# ╔═╡ 6ce65dbf-fb16-495f-a82a-d61b7ff948cf
md"""
## Parameterization
"""

# ╔═╡ af897133-5ab8-415a-9c6a-573e2ee88789
md"""
We use a slight variation of the parameterization in the September 2019 version of the paper. The utility from housing is $v(L) = \log(L)$.
"""

# ╔═╡ e7f88a10-db29-11ec-0da8-7f614bc0eae4
Base.@kwdef struct RedistributiveGrowthModel
	L̄ = 1 # supply of land
	ϕ = 0.2 # fraction with high human capital
	h̃ = 8/0.2 # inelastic supply of high-skilled labor - is this maybe wrong? see p. 22 in Doettling and Perotti 2019
	l̃ = 10/(1-0.2) # inelastic supply of low-skilled labor
	α = 0.33 # capital share
	η = 0.45 # relative productivity of intangible capital & high-skilled labor
	ω = 0.9 # fraction of intangibles that can be "stolen" by innovators
	ψ = 1. # cost for producing intangibles
	A = 1. # productivity
end

# ╔═╡ 3cf054a6-2779-4f32-af76-14a13fb4f467
mod = RedistributiveGrowthModel()

# ╔═╡ 16a03ff3-1b13-4841-adde-4f9f83e5af43
md"""
## Representative firm
"""

# ╔═╡ dc1ccbb2-9490-4446-83af-9848045a6f2e
md"""
We consider the special case $\rho \rightarrow 0$ in which the production function has a Cobb-Douglas form:

$$F(K, H, l, h) = A (H^\alpha h^{1-\alpha})^\eta (K^\alpha l^{1-\alpha})^{1-\eta}$$
"""

# ╔═╡ aa4b89ef-b941-42ba-ab60-e40f0741fb25
function F(K, H, l, h, (; A, η, α)) 
	A * (
		(H^α * h^(1-α))^η *
		(K^α * l^(1-α))^(1-η)
	)
end

# ╔═╡ 52952205-d855-4372-a98f-8859a631bbd7
md"""
1. Productivity of intangible capital $\eta$ $(@bind η_sl Slider(range(0, 1, length = 101), default=0.5, show_value=true))
2. Capital share $\alpha$ $(@bind α_sl Slider(range(0, 1, length = 101), default=0.5, show_value=true))
3. Common productivity factor $A$  $(@bind A_sl Slider(1:100, default=1, show_value=true))
"""

# ╔═╡ e7200c53-5563-4676-9572-2e944f3a7abe
md"""
Labor is supplied inelastically in this model so that $l=(1-\phi)\tilde{l}$ and $h=\phi \tilde{h}$. Therefore, we can write down the production function as a function of only $K$ and $H$:
"""

# ╔═╡ 26578a88-f4cc-462a-918d-c8362bd2d8c0
function F(K, H, (; A, η, α, ϕ, l̃, h̃)) 
	l = (1-ϕ) * l̃
	h = ϕ * h̃
	F(K, H, l, h, (; A, η, α))
end

# ╔═╡ 31d8ae5e-64ee-409f-b9f6-b3e3335c987c
md"""
We can compute the first derivatives of the production function numerically which correspond to the factor prices:
- price of physical capital $1+r$
- price of intangible capital $R_H$
- wage for manual workers $w$
- wage for high-skill workers $q$
"""

# ╔═╡ cc720fe0-2de8-4cbe-bad4-0527de8c9660
F(xx, par) = F(xx..., par)

# ╔═╡ 41d2fbe3-3ec9-451e-be3b-4908321f359d
let
	H_list = K_list = range(0.01, 1, length = 101)

	title = latexstring("Contour plot of \$Y(K, H, l = 1, h = 1)\$")
	
	contourf(
		K_list, H_list, (x, y) -> F(x, y, 1., 1., (; A=A_sl, 
		η=η_sl, α=α_sl)),
		title = title,
		xlabel = L"K", ylabel = L"H"
	)
end

# ╔═╡ cfe36e6e-50e5-4d0d-b6eb-caa2d2659b81
function get_prices(K, H, mod)

	(; ϕ, l̃, h̃) = mod
	
	l = (1-ϕ) * l̃
	h = ϕ * h̃
	xx = [K, H, l, h]
	
	oneplusr, R_H, w, q = ForwardDiff.gradient(x -> F(x, mod), xx)

	Y = F(xx, mod)
	check = Y - w * l - q * h - oneplusr * K - R_H * H

	(; check, oneplusr, R_H, w, q, Y)
end

# ╔═╡ 019589f3-1570-455b-86f2-9c06a42b7b11
get_prices(0.5, 1., mod)

# ╔═╡ 81c720e2-e702-4aa0-b0a4-5067c116ec59
md"""
## Steady state equilibrium
"""

# ╔═╡ e98af1be-d7ed-4f5f-b924-27e8fd41bf18
md"""
The equations that describe the steady state values of $\{K, H, Y, r, R_H, f, p\}$ (together with the production function) are given in the appendix of the paper:

$$1+r = \alpha (1-\eta) \frac{Y}{K}$$
$$R_H = \alpha \eta \frac{Y}{H}$$
$$H = \frac{\omega}{\psi} R_H$$
$$f = \frac{(1-\omega)R_H H}{r}$$
$$p = \frac{v'(\bar{L})}{r} = \frac{1}{\bar{L}r}$$
$$(1-\alpha)Y = p \bar{L} + f + K$$
"""

# ╔═╡ 633a25b9-54ae-4882-b73a-b1d388d186f7
md"""
## Exercise 1 (3 points)

👉 Provide brief derivations for equation 1 (1 point) and equation 4 (2 points) above.
"""

# ╔═╡ 0f68c9f7-4b5e-40c7-b392-9f8d2dccde0c
md"""
The firm solves the following profit maximisation problem:

$\max A(H^{\alpha}h^{1-\alpha})^{\eta}(K^{\alpha}l^{1-\alpha}){1-\eta} - wl - qh - (1+r)K - R_{H}H$

The FOC wrt. $K$: 

$1 + r = A(H^{\alpha}h^{1-\alpha})^{\eta}(l^{1-\alpha})^{1-\eta}\alpha(1 - \eta)K^{\alpha(1 - \eta) - 1}$

$1 + r = \alpha(1 - \eta)\frac{Y}{K}$

Which gives us equation 1. 

The household solves the following utility maximisation problem:

$\max_{c_t, L_t, S_t, D_t} c_{t+1} + v(L_{t}) + \lambda_{t}(y_{t} - p_{t}L_{t} - f_{t}S_{t} - D_{t}) + \mu_{t}(y_{t+1} + p_{t+1}L_{t} + (f_{t+1} + d_{t+1})S_{t} + (1 + r_{t+1})D_{t} - c_{t+1})$

The FOC wrt. $S_{t}$:

$\lambda_{t}f_{t} = \mu_{t}(f_{t+1} + d_{t+1})$

and $D_{t}$:

$\lambda_{t} = (1 + r_{t+1})\mu_{t}$

Then substitute in for $\lambda_{t}$:

$\mu_{t}(f_{t+1} + d_{t+1}) = f_{t}(1 + r_{t+1})\mu_{t}$

$f_{t+1} + d_{t+1} = f_{t}(1 + r_{t+1})$

In the steady-state, remove the time subscripts:

$f = \frac{d}{r}$

From the paper we have that $d = (1 - \omega)R_{H}H$. This gives us the required equation 4.
"""

# ╔═╡ d086f933-75ff-45e1-8b0c-88673f1a46dc
md"""
## Solving for the steady state
"""

# ╔═╡ 5cce5a48-5137-45d8-9182-e9e2da0992af
md"""
We use numerical methods to solve for the steady state. First, we reformulate the system of equations by substituting out the five variables $\{Y, r, R_H, f, p\}$, so that we end up with a system of just two equations as a function of $K$ and $H$:
"""

# ╔═╡ 93b1f04f-82cf-48e2-80eb-8de7dd3a2a8c
function model_equations_1(K, H, mod)

	(; α, η, ω, L̄, ϕ, l̃, A) = mod

	Y = F(K, H, mod)            # production function
	r = α * (1 - η) * Y/K - 1   # eq. 1 (rearranged)
	R_H = α * η * Y/H           # eq. 2
	f = ((1 - ω) * R_H * H) / r # eq. 4
	p = 1 / (L̄ * r)             # eq. 5

	return (; Y, r, R_H, f, p)

end

# ╔═╡ a30c1120-823b-4f75-928e-780fc61d723a
function model_equations_2(K, H, mod)

	(; Y, r, R_H, f, p) = model_equations_1(K, H, mod)

	(; α, ω, L̄, ψ) = mod
	
	eq_1 = H - ω/ψ * R_H                # eq. 3 (rearranged)
	eq_2 = (1 - α) * Y - p * L̄ - f - K  # eq. 6 (rearranged)
	
	return (eq_1, eq_2)

end

# ╔═╡ 90eb2948-ba30-482f-ab04-e633e11c510d
md"""
```eq_1``` and ```eq_2``` in the function above should be zero at the steady state values of $K$ and $H$. Consequently, the sum of the squares ```eq_1```² + ```eq_2```² should also be zero in this case. 

This means that we can find the steady state values of $K$ and $H$ by applying a minimization algorithm to ```eq_1```² + ```eq_2```². 

To make sure that the algorithm does not accidentally use negative values for $K$ or $H$, we write down the objective function in terms of $\log(K)$ and $\log(H)$. 

After running the minimization algorithm, we always need to check if the sum of squares is indeed zero (or at least extremely close to zero). 

Other solution algorithms are possible and probably better than this approach. See [this notebook](https://greimel.github.io/distributional-macroeconomics/notebooks_redistributive-growth-fabian/) with alternative solution methods for the redistributive growth model.
"""

# ╔═╡ bf487895-dca9-4c56-885e-cf62ea4619ed
function objective_function(log_K_log_H, mod)

	K = exp(log_K_log_H[1])
	H = exp(log_K_log_H[2])

	(eq_1, eq_2) = model_equations_2(K, H, mod)

	return eq_1^2 + eq_2^2

end

# ╔═╡ f8145deb-659c-4846-a6a5-bde4b2b07130
md"""
We need to initialize the minimization algorithm at values for $K$ and $H$ that are associated with a positive interest rate $r$. Otherwise, the algorithm may converge to another minimum with a negative interest rate that is not economically meaningful.

Below you can see that the interest rate associated with our starting values is indeed positive.
"""

# ╔═╡ 7c0d4877-8a50-4bdc-be44-00246473f7ee
begin 
	K_init = 0.4
	H_init = 1.
	model_equations_1(K_init, H_init, mod)
end

# ╔═╡ b12bd6fd-e7bc-45d0-a216-aa90a73ca3f9
md"""
Now we apply the minimization algorithm. The objective function is very close to 0 at the minimum that the algorithm found.
"""

# ╔═╡ 7f0cd31c-1466-4ecc-831f-9e9624b1c41e
res = optimize(x -> objective_function(x, mod), [log(K_init), log(H_init)])

# ╔═╡ fb1bf1b2-b5c1-44a7-b3f4-3f518fe19f84
md"""
Since the arguments of the objective function are $\log(K)$ and $\log(H)$, we need to exponentiate the minimizer to get the steady state values of $K$ and $H$:
"""

# ╔═╡ d19d64fa-b7e2-4844-94c9-26cd4ce4bc8a
(K, H) = exp.(Optim.minimizer(res))

# ╔═╡ 263cad70-dbec-4cb6-b9aa-ee1565a49f4e
md"""
To find the steady state values of $\{Y, r, R_H, f, p\}$, we put the steady state values of $K$ and $H$ into the equations that we have used to substitute out these five variables:
"""

# ╔═╡ 905f8df9-f455-425c-a377-514f2bfd8aee
model_equations_1(K, H, mod)

# ╔═╡ 37449817-f60c-44ef-b91b-1bc93f67bd4c
md"""
Moreover, we can get steady-state wages $w$ and $q$ by computing the numerical gradient of the production function:
"""

# ╔═╡ 58817926-b6d6-40a4-9a67-a87770e0963e
get_prices(K, H, mod)

# ╔═╡ bd656d98-2a68-4c5a-811f-2a1ace5d61d7
md"""
## Exercise 2 (1 point)

The steady state interest rate $r$ = $(round(model_equations_1(K, H, mod).r*100,digits=1))% seems quite big at a first glance. 

👉 Is the steady state interest rate in the model roughly consistent with interest rates in the real world? Provide a brief explanation. (max. 100 words)
"""

# ╔═╡ e9fcc415-f33e-4dbe-a422-792bf96e5974
answer_2 = md"""
We do not believe the model interest rate is consistent with interest rates in the real world. Specifically, the interest rate is lower in the real world. This may be because:

* No monetary policy or inflation in the model
	There is sufficient evidence that adding these elements change decision making (and interest rates) in both the real world and models

* The model parameters are not calibrated correctly
* Other shifters of the interest rate (demand and supply of funds) are not considered 
"""

# ╔═╡ 902217fd-d669-4324-8474-5ae2d0ff145f
md"""
## Secular trends
"""

# ╔═╡ 9a145cc8-cd00-4ac2-9e97-6e5107eb8a8a
md"""
The paper claims that a shift towards intangible capital $\eta$ $\uparrow$ in the model can explain the following macroeconomic trends:
- declining interest rates $r$ $\downarrow$
- increasing share of intangible capital $H/(H+K)$ $\uparrow$
- declining physical investment (scaled by GDP) $K/Y$ $\downarrow$
- increasing mortgage borrowing $m/Y$ $\uparrow$
- increasing house prices $p/Y$ $\uparrow$
- increasing stock prices $f/Y$ $\uparrow$
- increasing wage inequality $q/w$ $\uparrow$
"""

# ╔═╡ a84bf9a1-8f9c-4ada-8c18-8b6b74382b98
md"""
To confirm that an increase in $\eta$ indeed generates the secular trends listed above for the given parameterization, we compute the steady state for a slightly higher value of $\eta$ such as $\eta$ = $(round(mod.η+0.1, digits=2)) and compare the variables of interest in the two steady states.
"""

# ╔═╡ 63159b5d-b683-4e52-ac91-68f6a5d7e779
mod_η = RedistributiveGrowthModel(η=mod.η+0.1)

# ╔═╡ b8fe15be-197b-4e9f-992a-8d066c7f9904
model_equations_1(K_init, H_init, mod_η)

# ╔═╡ 4a2cd26a-0b5b-4b8b-8c81-457d37165b87
res_η = optimize(x -> objective_function(x, mod_η), [log(K_init), log(H_init)])

# ╔═╡ 60621201-5793-40de-b8d0-709496e986f2
(K_η, H_η) = exp.(Optim.minimizer(res_η))

# ╔═╡ 9d554cce-3cce-4bef-a151-d30a069fc295
md"""
The first row describes the steady state for the baseline value for $\eta$, the second row for $\eta$ = $(round(mod_η.η, digits=3)):
"""

# ╔═╡ 160a736a-36b6-433a-885c-2e320c736223
md"""
Below you can find two helper functions to compute the macroeconomic variables of interest for given steady state values $K$, $H$, and to compare macroeconomic variables across steady states:
"""

# ╔═╡ 8e2ef37d-9a68-4a09-a4f1-b137c386ee19
function compute_trends_variables(K, H, mod)

	(; Y, r, R_H, f, p) = model_equations_1(K, H, mod)

	(; ϕ, L̄, l̃) = mod

	(; w, q) = get_prices(K, H, mod)

	m = max(0, (1-ϕ) * (p * L̄ + f - w * l̃))

	H_HK = H/(H+K)
	K_Y = K/Y
	m_Y = m/Y
	p_Y = p/Y
	f_Y = f/Y
	q_w = q/w

	(; r, H_HK, K_Y, m_Y, p_Y, f_Y, q_w)

end

# ╔═╡ 12b1db67-23e7-4b60-95ac-f265e4db1597
begin 
	trends_vars = compute_trends_variables(K, H, mod)
	trends_vars_η = compute_trends_variables(K_η, H_η, mod_η)
	DataFrame([trends_vars, trends_vars_η])
end

# ╔═╡ 05f233c6-826b-4648-b21b-3fb682865812
function trends(trends_vars_1, trends_vars_0)
	for key in keys(trends_vars_0)
		if trends_vars_1[key] > trends_vars_0[key] + 1e-6
			sgn = "↑"
		elseif trends_vars_1[key] < trends_vars_0[key] - 1e-6
			sgn = "↓"
		else
			sgn = "→"
		end
		println(key, " " , sgn)
	end
end

# ╔═╡ b316d6a4-b55a-4f5b-b199-1a41f3c29ce9
trends(trends_vars_η, trends_vars)

# ╔═╡ a1972951-3ebb-4416-9c4b-bcb833f525f1
md"""
## Alternative growth drives
"""

# ╔═╡ 45984ce4-fc9b-4adf-922f-cbeacee0fdf4
md"""
In the previous section, we found out that a technological shift to intangible capital $\eta$ $\uparrow$ can explain the secular trends (at least qualitatively). But is it the only possible explanation of these trends?

In order to exclude other possible explanations, we need to consider alternative growth drivers and check which of the secular trends they can replicate and which not.

The following alternative growth drivers are already implemented in the model:
- greater ease of innovation $\psi$ $\downarrow$
- rising share of educated workers $\phi$ $\uparrow$
- rising productivity of capital relative to labor $\alpha$ $\uparrow$
- increased bargaining power for innovators over established firms $\omega$ $\uparrow$
"""

# ╔═╡ e68736e0-52ab-4282-bebf-08f529b214f9
md"""
## Exercise 3 (2.5 points)

👉 Pick one of the four alternative growth drivers listed above and conduct a comparison of steady states similar to the $\eta$ $\uparrow$ case. Which of the secular trends can this growth driver explain and which not? Provide a brief explanation for the changes in $\{r, H/(H+K), K/Y, m/Y, p/Y, f/Y, w/q\}$ that are generated by the parameter change that you consider. (max. 200 words)
"""

# ╔═╡ 8659bc54-5551-402a-b284-5e74ef6cd9d1
md"""
We choose to look at the rising share of educated workers. Therefore, we create a new steady state with a new value of ``\phi`` and compare the trends. 
"""

# ╔═╡ f13d0b20-fa76-4038-b9dc-d351e9fd5c6e
mod_ϕ = RedistributiveGrowthModel(ϕ = mod.ϕ + 0.1)

# ╔═╡ 360602ad-7605-42eb-a6fd-8aa0733b7f48
model_equations_2(K_init, H_init, mod_ϕ)

# ╔═╡ 7dc2275a-87b6-4efb-b142-fba5914ddb62
res_ϕ = optimize(x -> objective_function(x, mod_ϕ), [log(K_init), log(H_init)])

# ╔═╡ 82df387c-ab3f-407d-b1ee-4061145a5379
(K_ϕ, H_ϕ) = exp.(Optim.minimizer(res_ϕ))

# ╔═╡ 5ec321c8-a76e-46cd-9dbe-a2c74054895b
begin
	trends_vars_1 = compute_trends_variables(K, H, mod)
	trends_vars_1_ϕ = compute_trends_variables(K_ϕ, H_ϕ, mod_ϕ)
	DataFrame([trends_vars_1, trends_vars_1_ϕ])
end

# ╔═╡ 2f715a5f-32d8-4ac1-a001-acfeff572502
trends(trends_vars_1_ϕ, trends_vars_1)

# ╔═╡ 8772b001-b85c-4d24-9b82-4bd2b2f3af9a
answer_3 = md"""
The rise in educated workers gives the following trends:
* Interest rate falls:
	Directly due to K/Y rising in the model(discussed below); but intuitively because 
    there is an increase in savings 
* Decreasing share of intangible capital
	According to the paper, a higher ϕ should reduce investable assets, which reduces the interest rate and favours physical investments over intangible ones due to complementarity (Perotti and Döttling 2019, p. 24)
* Increasing physical capital investment
	A rise in ϕ leads to a higher MPK, so K/Y rises (since there are diminishing returns, Y does not increase by as much). 
* Fall in mortgage borrowing
	Because ϕ directly decreases the mortgage borrowing; and prices fall such that mortgage fall indirectly too. 
* Fall in house prices over $Y$
	A fall in interest rates leads to Y rising faster than house prices 
* Rise is stock prices
	Interest rates fall so the return on stocks rises (steady-state equation)
* Fall in wage inequality 
	The relative supply of high-skilled labour rises, which decreases the relative wage - reducing wage inequality. 
"""

# ╔═╡ b5df5021-ef85-49f1-ae28-391a7b55929c
md"""
## Exercise 4 (3.5 points)

An alternative growth driver are capital inflows from emerging countries into the developed world ("global savings glut"). These capital inflows can be incorporated into the model by adding an exogenous increase in savings $x$ to the steady state equations:

$$(1-\alpha + x)Y = p \bar{L} + f + K$$

👉 Add the exogenous increase in savings to the model and repeat exercise 3 for this alternative growth driver. (max. 200 words)
"""

# ╔═╡ b4791e0b-99e4-46b3-b68c-1150ca509a16
Base.@kwdef struct RedistributiveGrowthModel2
	L̄ = 1 # supply of land
	ϕ = 0.2 # fraction with high human capital
	h̃ = 8/0.2 # inelastic supply of high-skilled labor
	l̃ = 10/(1-0.2) # inelastic supply of low-skilled labor
	α = 0.33 # capital share
	η = 0.45 # relative productivity of intangible capital & high-skilled labor
	ω = 0.9 # fraction of intangibles that can be "stolen" by innovators
	ψ = 1. # cost for producing intangibles
	A = 1. # productivity
	s = 0. # saving
end

# ╔═╡ 296f8fc0-464f-48a4-8702-abbbce55207e
mod2 = RedistributiveGrowthModel2()

# ╔═╡ f654a2ca-ab66-484b-a02c-95cddfd50e5c
mod2s = RedistributiveGrowthModel2(s=mod2.s+0.2)

# ╔═╡ 7308d330-1acc-4ddb-9ce1-f12067f12448
function model_equations_3(K, H, mod)

	(; α, η, ω, L̄, ϕ, l̃, A, s) = mod

	Y = F(K, H, mod)            # production function
	r = α * (1 - η) * Y/K - 1   # eq. 1 (rearranged)
	R_H = α * η * Y/H           # eq. 2
	f = ((1 - ω) * R_H * H) / r # eq. 4
	p = 1 / (L̄ * r)             # eq. 5

	return (; Y, r, R_H, f, p)

end

# ╔═╡ cc0e0ddc-26f9-4381-975f-882581808f37
function model_equations_4(K, H, mod)

	(; Y, r, R_H, f, p) = model_equations_3(K, H, mod)

	(; α, ω, L̄, ψ, s) = mod
	
	eq_1 = H - ω/ψ * R_H                # eq. 3 (rearranged)
	eq_2 = (1 - α + s) * Y - p * L̄ - f - K  # eq. 6 (rearranged)
	
	return (eq_1, eq_2)

end

# ╔═╡ 9c69d403-a3c3-42c5-9f7b-30e1dc653bd6
function objective_function2(log_K_log_H, mod)

	K = exp(log_K_log_H[1])
	H = exp(log_K_log_H[2])

	(eq_1, eq_2) = model_equations_4(K, H, mod)

	return eq_1^2 + eq_2^2

end

# ╔═╡ ca5f7e05-0425-42c7-a704-fb04685d8281
begin 
	K_init2 = 0.4
	H_init2 = 1.
	model_equations_3(K_init2, H_init2, mod2s)
end

# ╔═╡ 6813b601-7bb5-45f3-ab37-279ac21f9786
res2s = optimize(x -> objective_function2(x, mod2s), [log(K_init2), log(H_init2)])

# ╔═╡ ff563901-710b-4604-a7d4-d61910826b7f
(K_2s, H_2s) = exp.(Optim.minimizer(res2s))

# ╔═╡ f79ddb37-d3d1-4dca-a819-3990ce519a6d
function compute_trends_variables2(K, H, mod)

	(; Y, r, R_H, f, p) = model_equations_3(K, H, mod)

	(; ϕ, L̄, l̃) = mod

	(; w, q) = get_prices(K, H, mod)

	m = max(0, (1-ϕ) * (p * L̄ + f - w * l̃))

	H_HK = H/(H+K)
	K_Y = K/Y
	m_Y = m/Y
	p_Y = p/Y
	f_Y = f/Y
	q_w = q/w

	(; r, H_HK, K_Y, m_Y, p_Y, f_Y, q_w)

end

# ╔═╡ e1ddc627-06cb-445f-82b2-159dd878b689
begin
	trends_vars_2s = compute_trends_variables2(K_2s, H_2s, mod2s)
	DataFrame([trends_vars, trends_vars_2s])
end

# ╔═╡ fd4c3c22-69e4-4b25-bc45-3cd958ca83a8
trends(trends_vars_2s, trends_vars)

# ╔═╡ c9bde4ee-2315-4d69-9981-2c7e3de869f6
answer_4 = md"""
The effect of capital inflows is the same as the shift towards intangible capital for $r$, mortgage borrowing, house and stock prices. 

A higher supply of savings decreases the interest rate. This leads to a rise in stock and house prices (they increase faster than $Y$). Mortgage borrowing rises because these prices rise. 

The increased savings from abroad can be invested into physcial capital, so $\frac{K}{Y}$ rises.

Interest rates fall, which favours physical investment. Therefore, $\frac{H}{H+K}$ falls. 

Lastly, there is no change in the wage inequality. This is because there is no change in the relative labour supply of high- and low-skilled workers. 
"""

# ╔═╡ 64b4a3ea-5511-4acd-b73a-3c043cff9137
md"""
## References
"""

# ╔═╡ 3453e438-994e-4600-89ce-df91e3070697
md"""
Perotti, E., & Döttling, R. (2019). Redistributive Growth.
"""

# ╔═╡ ca779c4e-35ca-43c1-be4f-624214e7f87e
md"""
## Before you submit ...

👉 Make sure you **do not** mention your name in the assignment. The assignments are graded anonymously.

👉 Make sure that that **all group members proofread** your submission.

👉 Make sure all the code is **well-documented**.

👉 Make sure that you are **within the word limit**. Short and concise answers are appreciated. Answers longer than the word limit will lead to deductions.

👉 Go to the very top of the notebook and click on the symbol in the very top-right corner. **Export a static html file** of this notebook for submission. (The source code is embedded in the html file.)
"""

# ╔═╡ b7374016-c764-4183-831f-4df4035bd156
md"""
# Appendix
"""

# ╔═╡ 0354492c-ca28-4642-a0f2-2734132a0800
md"""
## Acknowledgments

The visualization of the production function is taken from a notebook that was contributed by [Andrea Titton](https://github.com/NoFishLikeIan).
"""

# ╔═╡ f282c525-6a9f-4145-83ed-934d15a62456
md"""
## Word limit functions
"""

# ╔═╡ b272b3b6-0416-4b13-aa58-548033deaafa
function wordcount(text)
	stripped_text = strip(replace(string(text), r"\s" => " "))
   	words = split(stripped_text, (' ', '-', '.', ',', ':', '_', '"', ';', '!', '\''))
   	length(filter(!=(""), words))
end

# ╔═╡ 8b68e019-c248-4ca6-a14d-e351325f1a2a
show_words(answer) = md"_approximately $(wordcount(answer)) words_"

# ╔═╡ d9382077-9e8f-478e-8fb0-2a9ce1b75f63
begin
	admonition(kind, title, text) = Markdown.MD(Markdown.Admonition(kind, title, [text]))
	hint(text, title="Hint")       = admonition("hint",    title, text)
	warning(text, title="Warning") = admonition("warning", title, text)
	danger(text, title="Danger")   = admonition("danger",  title, text)
	correct(text, title="Correct") = admonition("correct", title, text)

	almost(text) = warning(text, "Almost there!")
	keep_working(text=md"The answer is not quite right.") = danger(text, "Keep working on it!")
	yays = [md"Great!", md"Yay ❤", md"Great! 🎉", md"Well done!", md"Keep it up!", md"Good job!", md"Awesome!", md"You got the right answer!", md"Let's move on to the next section."]
	got_it(text=rand(yays)) = correct(text, "Got it!")
end

# ╔═╡ 568c0fa6-0759-45ec-89a7-f15ade254ba2
function show_words_limit(answer, limit)
	count = wordcount(answer)
	if count < 1.02 * limit
		return show_words(answer)
	else
		return almost(md"You are at $count words. Please shorten your text a bit, to get **below $limit words**.")
	end
end

# ╔═╡ 7b77b272-6832-4f21-b4a3-5fe88d0bd209
show_words_limit(answer_2, 100)

# ╔═╡ 117cb9fb-4a30-4764-9dec-4b273fdba205
show_words_limit(answer_3, 200)

# ╔═╡ 3062ccf9-bb99-420a-b0a6-d1f6aa2b4a04
show_words_limit(answer_4, 200)

# ╔═╡ 5eb25f2f-bd4f-4995-a07a-b25134a9a509
md"""
## Imported packages
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
ForwardDiff = "f6369f11-7733-5829-9624-2563aa707210"
LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
Optim = "429524aa-4258-5aef-a3af-852621145aeb"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"

[compat]
DataFrames = "~1.3.4"
ForwardDiff = "~0.10.30"
LaTeXStrings = "~1.3.0"
Optim = "~1.7.0"
Plots = "~1.29.0"
PlutoUI = "~0.7.39"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.2"
manifest_format = "2.0"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "af92965fb30777147966f58acb05da51c5616b5f"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.3"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.ArrayInterfaceCore]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "8a9c02f9d323d4dd8a47245abb106355bf7b45e6"
uuid = "30b0a656-2188-435a-8636-2ec0e6a096e2"
version = "0.1.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "9489214b993cd42d17f44c36e359bf6a7c919abf"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.15.0"

[[deps.ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "1e315e3f4b0b7ce40feded39c73049692126cf53"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.3"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "7297381ccb5df764549818d9a7d57e45f1057d30"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.18.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "a985dc37e357a3b22b260a5def99f3530fb415d3"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.2"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "d08c20eef1f2cbc6e60fd3612ac4340b89fea322"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.9"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "b153278a25dd42c65abbf4e62344f9d22e59191b"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.43.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "fb5f5316dd3fd4c5e7c30a24d50643b73e37cd40"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.10.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "daa21eb85147f72e41f6352a57fccea377e310a9"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.3.4"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "cc1a8e22627f33c789ab60b36a9132ac050bbf75"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.12"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.DiffResults]]
deps = ["StaticArrays"]
git-tree-sha1 = "c18e98cba888c6c25d1c3b048e4b3380ca956805"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.0.3"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "28d605d9a0ac17118fe2c5e9ce0fbb76c3ceb120"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.11.0"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3f3a2501fa7236e9b911e0f7a588c657e822bb6d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.3+0"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bad72f730e9e91c08d9427d5e8db95478a3c323d"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.4.8+0"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d8a578692e3077ac998b50c0217dfd67f21d1e5f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.0+0"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "246621d23d1f43e3b9c368bf3b72b2331a27c286"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.13.2"

[[deps.FiniteDiff]]
deps = ["ArrayInterfaceCore", "LinearAlgebra", "Requires", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "4fc79c0f63ddfdcdc623a8ce36623346a7ce9ae4"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.12.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "2f18915445b248731ec5db4e4a17e451020bf21e"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.30"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "51d2dfe8e590fbd74e7a842cf6d13d8a2f45dc01"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.6+0"

[[deps.GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "RelocatableFolders", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "b316fd18f5bc025fedcb708332aecb3e13b9b453"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.64.3"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "1e5490a51b4e9d07e8b04836f6008f46b48aaa87"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.64.3+0"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "83ea630384a13fc4f002b77690bc0afeb4255ac9"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.2"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "a32d672ac2c967f3deb8a81d828afc739c838a06"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+2"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "0fa77022fe4b511826b39c894c90daf5fce3334a"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.17"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[deps.IniFile]]
git-tree-sha1 = "f550e6e32074c939295eb5ea6de31849ac2c9625"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.1"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "336cc738f03e069ef2cac55a104eb823455dca75"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.4"

[[deps.InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[deps.IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b53380851c6e6664204efb2e62cd24fa5c47e4ba"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.2+0"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "Printf", "Requires"]
git-tree-sha1 = "46a39b9c58749eefb5f2dc1178cb8fab5332b1ab"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.15"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "7739f837d6447403596a75d19ed01fd08d6f56bf"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.3.0+3"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "c9551dd26e31ab17b86cbd00c2ede019c08758eb"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+1"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[deps.LineSearches]]
deps = ["LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "Printf"]
git-tree-sha1 = "f27132e551e959b3667d8c93eae90973225032dd"
uuid = "d3d80556-e9d4-5f37-9878-2ab0fcc64255"
version = "7.1.1"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "09e4b894ce6a976c354a69041a04748180d43637"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.15"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "50310f934e55e5ca3912fb941dec199b49ca9b68"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.2"

[[deps.NaNMath]]
git-tree-sha1 = "b086b7ea07f8e38cf122f5016af580881ac914fe"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.7"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ab05aa4cc89736e95915b01e7279e61b1bfe33b8"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.14+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.Optim]]
deps = ["Compat", "FillArrays", "ForwardDiff", "LineSearches", "LinearAlgebra", "NLSolversBase", "NaNMath", "Parameters", "PositiveFactorizations", "Printf", "SparseArrays", "StatsBase"]
git-tree-sha1 = "7a28efc8e34d5df89fc87343318b0a8add2c4021"
uuid = "429524aa-4258-5aef-a3af-852621145aeb"
version = "1.7.0"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "1285416549ccfcdf0c50d4997a94331e88d68413"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.3.1"

[[deps.Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Statistics"]
git-tree-sha1 = "8162b2f8547bc23876edd0c5181b27702ae58dce"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "3.0.0"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "bb16469fd5224100e422f0b027d26c5a25de1200"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.2.0"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun", "Unzip"]
git-tree-sha1 = "d457f881ea56bbfa18222642de51e0abf67b9027"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.29.0"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "8d1f54886b9037091edf146b517989fc4a09efec"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.39"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.PositiveFactorizations]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "17275485f373e6673f7e7f97051f703ed5b15b20"
uuid = "85a6dd25-e78a-55b7-8502-1745935b8125"
version = "0.2.4"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "dfb54c4e414caa595a1f2ed759b160f5a3ddcba5"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.3.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "c6c0f690d0cc7caddb74cef7aa847b824a16b256"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+1"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RecipesBase]]
git-tree-sha1 = "6bf3f380ff52ce0832ddd3a2a7b9538ed1bcca7d"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.2.1"

[[deps.RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "dc1e451e15d90347a7decc4221842a022b011714"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.5.2"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "cdbd3b1338c72ce29d9584fdbe9e9b70eeb5adca"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "0.1.3"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "bc40f042cfcc56230f781d92db71f0e21496dffd"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.1.5"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "cd56bf18ed715e8b09f06ef8c6b781e6cdc49911"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.4.4"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "c82aaa13b44ea00134f8c9c89819477bd3986ecd"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.3.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "8977b17906b0a1cc74ab2e3a05faa16cf08a8291"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.16"

[[deps.StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "e75d82493681dfd884a357952bbd7ab0608e1dc3"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.7"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "5ce79ce186cc678bbb5c5681ca3379d1ddae11a1"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.7.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.Tricks]]
git-tree-sha1 = "6bac775f2d42a611cdfcd1fb217ee719630c4175"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.6"

[[deps.URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unzip]]
git-tree-sha1 = "34db80951901073501137bdbc3d5a8e7bbd06670"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.1.2"

[[deps.Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "3e61f0b86f90dacb0bc0e73a0c5a83f6a8636e23"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.19.0+0"

[[deps.Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4528479aa01ee1b3b4cd0e6faef0e04cf16466da"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.25.0+0"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[deps.Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[deps.Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[deps.Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[deps.Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[deps.Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[deps.Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[deps.Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[deps.Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[deps.Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e45044cd873ded54b6a5bac0eb5c971392cf1927"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.2+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "ece2350174195bb31de1a63bea3a41ae1aa593b6"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "0.9.1+5"
"""

# ╔═╡ Cell order:
# ╟─b5f3a5a5-206d-49ae-9b15-612f22cf3bfe
# ╟─578fba17-11eb-4057-8f18-fb7835e701d6
# ╟─6ce65dbf-fb16-495f-a82a-d61b7ff948cf
# ╟─af897133-5ab8-415a-9c6a-573e2ee88789
# ╠═e7f88a10-db29-11ec-0da8-7f614bc0eae4
# ╠═3cf054a6-2779-4f32-af76-14a13fb4f467
# ╟─16a03ff3-1b13-4841-adde-4f9f83e5af43
# ╟─dc1ccbb2-9490-4446-83af-9848045a6f2e
# ╠═aa4b89ef-b941-42ba-ab60-e40f0741fb25
# ╟─52952205-d855-4372-a98f-8859a631bbd7
# ╟─41d2fbe3-3ec9-451e-be3b-4908321f359d
# ╟─e7200c53-5563-4676-9572-2e944f3a7abe
# ╠═26578a88-f4cc-462a-918d-c8362bd2d8c0
# ╟─31d8ae5e-64ee-409f-b9f6-b3e3335c987c
# ╠═cc720fe0-2de8-4cbe-bad4-0527de8c9660
# ╠═cfe36e6e-50e5-4d0d-b6eb-caa2d2659b81
# ╠═019589f3-1570-455b-86f2-9c06a42b7b11
# ╟─81c720e2-e702-4aa0-b0a4-5067c116ec59
# ╟─e98af1be-d7ed-4f5f-b924-27e8fd41bf18
# ╟─633a25b9-54ae-4882-b73a-b1d388d186f7
# ╟─0f68c9f7-4b5e-40c7-b392-9f8d2dccde0c
# ╟─d086f933-75ff-45e1-8b0c-88673f1a46dc
# ╟─5cce5a48-5137-45d8-9182-e9e2da0992af
# ╠═93b1f04f-82cf-48e2-80eb-8de7dd3a2a8c
# ╠═a30c1120-823b-4f75-928e-780fc61d723a
# ╟─90eb2948-ba30-482f-ab04-e633e11c510d
# ╠═bf487895-dca9-4c56-885e-cf62ea4619ed
# ╟─f8145deb-659c-4846-a6a5-bde4b2b07130
# ╠═7c0d4877-8a50-4bdc-be44-00246473f7ee
# ╟─b12bd6fd-e7bc-45d0-a216-aa90a73ca3f9
# ╠═7f0cd31c-1466-4ecc-831f-9e9624b1c41e
# ╟─fb1bf1b2-b5c1-44a7-b3f4-3f518fe19f84
# ╠═d19d64fa-b7e2-4844-94c9-26cd4ce4bc8a
# ╟─263cad70-dbec-4cb6-b9aa-ee1565a49f4e
# ╠═905f8df9-f455-425c-a377-514f2bfd8aee
# ╟─37449817-f60c-44ef-b91b-1bc93f67bd4c
# ╠═58817926-b6d6-40a4-9a67-a87770e0963e
# ╟─bd656d98-2a68-4c5a-811f-2a1ace5d61d7
# ╟─e9fcc415-f33e-4dbe-a422-792bf96e5974
# ╟─7b77b272-6832-4f21-b4a3-5fe88d0bd209
# ╟─902217fd-d669-4324-8474-5ae2d0ff145f
# ╟─9a145cc8-cd00-4ac2-9e97-6e5107eb8a8a
# ╟─a84bf9a1-8f9c-4ada-8c18-8b6b74382b98
# ╠═63159b5d-b683-4e52-ac91-68f6a5d7e779
# ╠═b8fe15be-197b-4e9f-992a-8d066c7f9904
# ╠═4a2cd26a-0b5b-4b8b-8c81-457d37165b87
# ╠═60621201-5793-40de-b8d0-709496e986f2
# ╟─9d554cce-3cce-4bef-a151-d30a069fc295
# ╠═12b1db67-23e7-4b60-95ac-f265e4db1597
# ╠═b316d6a4-b55a-4f5b-b199-1a41f3c29ce9
# ╟─160a736a-36b6-433a-885c-2e320c736223
# ╠═8e2ef37d-9a68-4a09-a4f1-b137c386ee19
# ╠═05f233c6-826b-4648-b21b-3fb682865812
# ╟─a1972951-3ebb-4416-9c4b-bcb833f525f1
# ╟─45984ce4-fc9b-4adf-922f-cbeacee0fdf4
# ╟─e68736e0-52ab-4282-bebf-08f529b214f9
# ╟─8659bc54-5551-402a-b284-5e74ef6cd9d1
# ╠═f13d0b20-fa76-4038-b9dc-d351e9fd5c6e
# ╠═360602ad-7605-42eb-a6fd-8aa0733b7f48
# ╠═7dc2275a-87b6-4efb-b142-fba5914ddb62
# ╠═82df387c-ab3f-407d-b1ee-4061145a5379
# ╠═5ec321c8-a76e-46cd-9dbe-a2c74054895b
# ╠═2f715a5f-32d8-4ac1-a001-acfeff572502
# ╟─8772b001-b85c-4d24-9b82-4bd2b2f3af9a
# ╟─117cb9fb-4a30-4764-9dec-4b273fdba205
# ╟─b5df5021-ef85-49f1-ae28-391a7b55929c
# ╠═b4791e0b-99e4-46b3-b68c-1150ca509a16
# ╠═296f8fc0-464f-48a4-8702-abbbce55207e
# ╠═f654a2ca-ab66-484b-a02c-95cddfd50e5c
# ╠═7308d330-1acc-4ddb-9ce1-f12067f12448
# ╠═cc0e0ddc-26f9-4381-975f-882581808f37
# ╠═9c69d403-a3c3-42c5-9f7b-30e1dc653bd6
# ╠═ca5f7e05-0425-42c7-a704-fb04685d8281
# ╠═6813b601-7bb5-45f3-ab37-279ac21f9786
# ╠═ff563901-710b-4604-a7d4-d61910826b7f
# ╠═f79ddb37-d3d1-4dca-a819-3990ce519a6d
# ╠═e1ddc627-06cb-445f-82b2-159dd878b689
# ╠═fd4c3c22-69e4-4b25-bc45-3cd958ca83a8
# ╟─c9bde4ee-2315-4d69-9981-2c7e3de869f6
# ╟─3062ccf9-bb99-420a-b0a6-d1f6aa2b4a04
# ╟─64b4a3ea-5511-4acd-b73a-3c043cff9137
# ╟─3453e438-994e-4600-89ce-df91e3070697
# ╟─ca779c4e-35ca-43c1-be4f-624214e7f87e
# ╟─b7374016-c764-4183-831f-4df4035bd156
# ╟─0354492c-ca28-4642-a0f2-2734132a0800
# ╟─f282c525-6a9f-4145-83ed-934d15a62456
# ╠═b272b3b6-0416-4b13-aa58-548033deaafa
# ╠═8b68e019-c248-4ca6-a14d-e351325f1a2a
# ╠═568c0fa6-0759-45ec-89a7-f15ade254ba2
# ╠═d9382077-9e8f-478e-8fb0-2a9ce1b75f63
# ╟─5eb25f2f-bd4f-4995-a07a-b25134a9a509
# ╠═06657523-1871-4f45-a7a1-24e67df068b2
# ╠═30e81715-4076-4961-b95f-77e13279fbc8
# ╠═dbe5a87e-cee5-49c3-b8fe-dc8dbbd55650
# ╠═dfbf76d4-fd41-4481-978f-d6a690b03c70
# ╠═87c8692c-d18f-4c3d-89bd-b7d270f12e64
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
