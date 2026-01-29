#########################################
##        Module: modules_eda.py       ##
#########################################

# Import necessary libraries #
##############################

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# ----------------------------------------------------#

## Function to analyze distinct and missing values in a DataFrame ##
####################################################################


def eda(df, variables, categorical = False, order_asc=False):
    
    """
    Build a DataFrame showing distinct values (if categorical=True), missing values count 
    and percentage for given variables for given DataFrame and subset of variables.

    Parameters:
        df (pd.DataFrame): The DataFrame to analyze.
        variables (list): List of variables to check for missing values.
        categorical (bool): If True, include distinct values count.
        order_asc (bool): If True, sort the result in ascending order of missing count.
    """

    eda_df = pd.DataFrame({
        'Variable': variables,
        'Missing_Count': df[variables].isna().sum().values,
        'Missing_Percentage': (df[variables].isna().sum() / len(df) *100).round(2).values
    })

 
    if categorical:
        eda_df['Distinct_Values_Count'] = df[variables].nunique().values
        return eda_df.sort_values(by=['Missing_Count', 'Distinct_Values_Count'], ascending=order_asc)

    else:
        return eda_df.sort_values('Missing_Count', ascending=order_asc)


# ----------------------------------------------------#

## Plot categorial variable (average default rate and proportion by class) ##
#############################################################################

def plot_categorical_default_rate(home_credit, variable, name_var= None):

    """
    Plot average default rate and class proportion for a given categorical variable.
    Parameters:
        home_credit (pd.DataFrame): The DataFrame containing the data.
        variable (str): The categorical variable to analyze.
        name_var (str): The name of the variable for plot title.

    """
    # Set variable name for title if not provided
    if name_var is None:
        name_var = variable

    home_credit_null = home_credit[[variable,'TARGET']].copy()
    home_credit_null.replace(np.nan,'Other_NULL', inplace=True)
    categories_target_means = home_credit_null.groupby(variable)['TARGET'].mean().sort_values(ascending=False) * 100
    categories_pct= home_credit_null[variable].value_counts(normalize=True).reindex(categories_target_means.index) * 100

    fig,ax1= plt.subplots(figsize=(9, 5.4))

    # Default rate bar plot
    max_height = categories_target_means.max() + 2
    step = round(max_height / 10 , 0)
    categories_target_means.plot(kind='bar', color='skyblue', ax=ax1, edgecolor='black', width=0.6)
    ax1.set_title(f'{name_var} Average Default Rate by Class', fontsize=15, pad=14)


    # Main title
    ax1.set_title(f'{name_var} Average Default Rate by Class', fontsize=15, pad=28)
    fig.suptitle('(% representing class proportion)', fontsize=12, y=0.865)

    ax1.set_ylabel('Default Rate (%)', fontsize=12, labelpad=11)
    ax1.set_xlabel('', labelpad=10)
    ax1.set_yticks(np.arange(0, round(max_height,1), step))
    ax1.set_ylim(0, max_height)
    ax1.grid(axis='y', linestyle='--', alpha=0.5)

    # Class proportion percentage annotations
    for i, (bar_height, pct) in enumerate(zip(categories_target_means, categories_pct)):
        ax1.text(i, bar_height + 0.3, f'{round(pct,1)}%', 
                ha='center', va='bottom', fontsize=10)

    plt.tight_layout()
    plt.show()


#----------------------------------------------------#